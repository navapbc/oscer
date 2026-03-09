# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchDocAiResultsJob, type: :job do
  let(:user) { create(:user) }
  let(:staged_doc) { create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending") }
  let(:service) { instance_double(DocumentStagingService) }

  before do
    allow(DocumentStagingService).to receive(:new).and_return(service)
  end

  describe "#perform" do
    context "when all documents are complete" do
      before do
        allow(service).to receive(:fetch_results).and_return([])
      end

      it "calls fetch_results on the service" do
        described_class.perform_now([ staged_doc.id ])
        expect(service).to have_received(:fetch_results).with(staged_document_ids: [ staged_doc.id ])
      end

      it "does not re-enqueue" do
        expect {
          described_class.perform_now([ staged_doc.id ])
        }.not_to have_enqueued_job(described_class)
      end
    end

    context "when some documents are still pending" do
      before do
        allow(service).to receive(:fetch_results).and_return([ staged_doc.id ])
      end

      it "re-enqueues for still-pending documents" do
        expect {
          described_class.perform_now([ staged_doc.id ], attempt: 1)
        }.to have_enqueued_job(described_class).with([ staged_doc.id ], attempt: 2)
      end
    end

    context "when max attempts reached" do
      before do
        allow(service).to receive(:fetch_results).and_return([ staged_doc.id ])
      end

      it "does not re-enqueue" do
        expect {
          described_class.perform_now([ staged_doc.id ], attempt: 5)
        }.not_to have_enqueued_job(described_class)
      end

      it "marks remaining documents as failed" do
        described_class.perform_now([ staged_doc.id ], attempt: 5)
        staged_doc.reload
        expect(staged_doc.status).to eq("failed")
      end
    end
  end
end
