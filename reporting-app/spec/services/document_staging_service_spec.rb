# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentStagingService do
  let(:doc_ai_service) { instance_double(DocAiService) }
  let(:service) { described_class.new(doc_ai_service: doc_ai_service) }
  let(:user) { create(:user) }

  let(:file) do
    tempfile = Tempfile.new([ "payslip", ".pdf" ])
    tempfile.write("%PDF-1.4 test")
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "payslip.pdf")
  end

  let(:submit_response) { { "jobId" => "abc-123", "status" => "not_started" } }

  describe "#submit" do
    before do
      allow(doc_ai_service).to receive(:analyze_async).and_return(submit_response)
      allow(FetchDocAiResultsJob).to receive(:set).and_return(FetchDocAiResultsJob)
      allow(FetchDocAiResultsJob).to receive(:perform_later)
    end

    it "creates StagedDocument records for each file" do
      result = service.submit(files: [ file ], user: user)
      expect(result.size).to eq(1)
      expect(result.first).to be_a(StagedDocument)
      expect(result.first).to be_persisted
      expect(result.first.user_id).to eq(user.id)
    end

    it "sets status to pending" do
      result = service.submit(files: [ file ], user: user)
      expect(result.first.status).to eq("pending")
    end

    it "stores the doc_ai_job_id from the async response" do
      result = service.submit(files: [ file ], user: user)
      expect(result.first.doc_ai_job_id).to eq("abc-123")
    end

    it "calls analyze_async on the doc_ai_service for each file" do
      service.submit(files: [ file ], user: user)
      expect(doc_ai_service).to have_received(:analyze_async).once
    end

    it "enqueues FetchDocAiResultsJob" do
      result = service.submit(files: [ file ], user: user)
      expect(FetchDocAiResultsJob).to have_received(:set).with(wait: 1.minute)
      expect(FetchDocAiResultsJob).to have_received(:perform_later).with([ result.first.id ])
    end

    context "when analyze_async returns nil (service error)" do
      before do
        allow(doc_ai_service).to receive(:analyze_async).and_return(nil)
      end

      it "marks the staged document as failed" do
        result = service.submit(files: [ file ], user: user)
        expect(result.first.status).to eq("failed")
      end

      it "still enqueues the job for non-failed documents" do
        service.submit(files: [ file ], user: user)
        expect(FetchDocAiResultsJob).not_to have_received(:set)
      end
    end

    context "with multiple files" do
      let(:file2) do
        tempfile = Tempfile.new([ "w2", ".pdf" ])
        tempfile.write("%PDF-1.4 test2")
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "w2.pdf")
      end

      it "creates a staged document for each file" do
        result = service.submit(files: [ file, file2 ], user: user)
        expect(result.size).to eq(2)
      end
    end

    context "with too many files" do
      let(:files) do
        3.times.map do |i|
          tempfile = Tempfile.new([ "doc#{i}", ".pdf" ])
          tempfile.write("%PDF-1.4 test#{i}")
          tempfile.rewind
          Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "doc#{i}.pdf")
        end
      end

      it "raises a validation error" do
        expect { service.submit(files: files, user: user) }
          .to raise_error(DocumentStagingService::ValidationError, /maximum of 2 files/i)
      end
    end

    context "with invalid file type" do
      let(:invalid_file) do
        tempfile = Tempfile.new([ "test", ".txt" ])
        tempfile.write("hello world")
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "test.txt")
      end

      it "raises a validation error even if browser claims it is PDF" do
        expect { service.submit(files: [ invalid_file ], user: user) }
          .to raise_error(DocumentStagingService::ValidationError, /file type text\/plain is not allowed/i)
      end
    end

    context "with file too large" do
      let(:large_file) do
        tempfile = Tempfile.new([ "large", ".pdf" ])
        # Write some data to make it actually have a size
        tempfile.write("a" * 100)
        tempfile.rewind
        uploaded_file = Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "large.pdf")
        allow(uploaded_file).to receive(:size).and_return(31.megabytes)
        uploaded_file
      end

      it "raises a validation error" do
        expect { service.submit(files: [ large_file ], user: user) }
          .to raise_error(DocumentStagingService::ValidationError, /exceeds the maximum allowed size/i)
      end
    end

    context "with no files" do
      it "raises a validation error" do
        expect { service.submit(files: [], user: user) }
          .to raise_error(DocumentStagingService::ValidationError, /at least one file/i)
      end
    end
  end

  describe "#fetch_results" do
    let(:staged_doc) { create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending") }

    context "when the job is completed" do
      let(:result) do
        DocAiResult.build(
          "job_id" => "abc-123",
          "status" => "completed",
          "matchedDocumentClass" => "Payslip",
          "fields" => { "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 } }
        )
      end

      before do
        allow(DocAiResult::REGISTRY).to receive(:keys).and_return(%w[Payslip W2])
        allow(doc_ai_service).to receive(:check_status).with(job_id: "abc-123").and_return(result)
      end

      it "updates the staged document to validated" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.status).to eq("validated")
      end

      it "stores the matched document class" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.doc_ai_matched_class).to eq("Payslip")
      end

      it "stores the extracted fields" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.extracted_fields).to include("currentgrosspay")
      end

      it "sets validated_at" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.validated_at).to be_present
      end
    end

    context "when the job is still processing" do
      let(:processing_response) { { "job_id" => "abc-123", "status" => "processing" } }

      before do
        allow(doc_ai_service).to receive(:check_status).with(job_id: "abc-123").and_return(processing_response)
      end

      it "leaves the staged document as pending" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.status).to eq("pending")
      end

      it "returns the still-pending document ids" do
        result = service.fetch_results(staged_document_ids: [ staged_doc.id ])
        expect(result).to eq([ staged_doc.id ])
      end
    end

    context "when check_status returns nil (service error)" do
      before do
        allow(doc_ai_service).to receive(:check_status).with(job_id: "abc-123").and_return(nil)
      end

      it "marks the staged document as failed" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.status).to eq("failed")
      end
    end

    context "when the result has an unrecognized document class" do
      let(:result) do
        DocAiResult.build(
          "job_id" => "abc-123",
          "status" => "completed",
          "matchedDocumentClass" => "Unknown",
          "fields" => {}
        )
      end

      before do
        allow(DocAiResult::REGISTRY).to receive(:keys).and_return(%w[Payslip W2])
        allow(doc_ai_service).to receive(:check_status).with(job_id: "abc-123").and_return(result)
      end

      it "marks the staged document as rejected" do
        service.fetch_results(staged_document_ids: [ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.status).to eq("rejected")
      end
    end

    it "only loads pending staged documents" do
      validated_doc = create(:staged_document, :validated, user_id: user.id, doc_ai_job_id: "def-456")
      allow(doc_ai_service).to receive(:check_status)

      service.fetch_results(staged_document_ids: [ staged_doc.id, validated_doc.id ])
      expect(doc_ai_service).to have_received(:check_status).once
    end
  end
end
