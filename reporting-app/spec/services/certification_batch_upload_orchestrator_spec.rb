# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadOrchestrator do
  let(:adapter) { instance_double(Storage::S3Adapter, object_exists?: true) }
  let(:orchestrator) { described_class.new(storage_adapter: adapter) }
  let(:user) { create(:user) }

  describe "#initiate" do
    context "when file exists in storage" do
      it "creates CertificationBatchUpload record" do
        expect {
          orchestrator.initiate(
            source_type: :ui,
            filename: "members.csv",
            storage_key: "batch-uploads/uuid/members.csv",
            uploader: user
          )
        }.to change(CertificationBatchUpload, :count).by(1)
      end

      it "sets storage_key instead of file attachment" do
        batch_upload = orchestrator.initiate(
          source_type: :api,
          filename: "data.csv",
          storage_key: "batch-uploads/uuid/data.csv",
          uploader: user
        )

        expect(batch_upload.storage_key).to eq("batch-uploads/uuid/data.csv")
        expect(batch_upload.file).not_to be_attached
        expect(batch_upload.source_type).to eq("api")
        expect(batch_upload.filename).to eq("data.csv")
        expect(batch_upload.uploader).to eq(user)
      end

      it "sets status to pending" do
        batch_upload = orchestrator.initiate(
          source_type: :ui,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(batch_upload.status).to eq("pending")
        expect(batch_upload).to be_pending
      end

      it "enqueues processing job" do
        expect {
          orchestrator.initiate(
            source_type: :ui,
            filename: "test.csv",
            storage_key: "batch-uploads/uuid/test.csv",
            uploader: user
          )
        }.to have_enqueued_job(ProcessCertificationBatchUploadJob)
      end

      it "returns the created batch upload" do
        result = orchestrator.initiate(
          source_type: :api,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(result).to be_a(CertificationBatchUpload)
        expect(result).to be_persisted
        expect(result.id).to be_present
      end

      it "validates storage key before creating record" do
        allow(adapter).to receive(:object_exists?)
          .with(key: "batch-uploads/uuid/test.csv")
          .and_return(true)

        orchestrator.initiate(
          source_type: :ui,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(adapter).to have_received(:object_exists?)
          .with(key: "batch-uploads/uuid/test.csv")
      end
    end

    context "when file does not exist in storage" do
      before do
        allow(adapter).to receive(:object_exists?).and_return(false)
      end

      it "raises FileNotFoundError" do
        expect {
          orchestrator.initiate(
            source_type: :ui,
            filename: "missing.csv",
            storage_key: "batch-uploads/uuid/missing.csv",
            uploader: user
          )
        }.to raise_error(
          CertificationBatchUploadOrchestrator::FileNotFoundError,
          /File not found in storage/
        )
      end

      it "does not create batch upload record" do
        initial_count = CertificationBatchUpload.count

        expect {
          orchestrator.initiate(
            source_type: :ui,
            filename: "missing.csv",
            storage_key: "batch-uploads/uuid/missing.csv",
            uploader: user
          )
        }.to raise_error(CertificationBatchUploadOrchestrator::FileNotFoundError)

        expect(CertificationBatchUpload.count).to eq(initial_count)
      end

      it "does not enqueue processing job" do
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear

        expect do
          orchestrator.initiate(
            source_type: :ui,
            filename: "missing.csv",
            storage_key: "batch-uploads/uuid/missing.csv",
            uploader: user
          )
        end.to raise_error(CertificationBatchUploadOrchestrator::FileNotFoundError)

        expect(ProcessCertificationBatchUploadJob).not_to have_been_enqueued
      end
    end

    context "with different source types" do
      it "handles :ui source" do
        batch_upload = orchestrator.initiate(
          source_type: :ui,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(batch_upload.source_type).to eq("ui")
        expect(batch_upload).to be_ui
      end

      it "handles :api source" do
        batch_upload = orchestrator.initiate(
          source_type: :api,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(batch_upload.source_type).to eq("api")
        expect(batch_upload).to be_api
      end

      it "handles :storage_event source" do
        batch_upload = orchestrator.initiate(
          source_type: :storage_event,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(batch_upload.source_type).to eq("storage_event")
        expect(batch_upload).to be_storage_event
      end
    end

    context "when adapter not provided" do
      let(:orchestrator) { described_class.new }

      before do
        # Set storage_adapter on Rails config for this test
        Rails.application.config.storage_adapter = adapter
      end

      it "uses Rails.application.config.storage_adapter" do
        orchestrator.initiate(
          source_type: :ui,
          filename: "test.csv",
          storage_key: "batch-uploads/uuid/test.csv",
          uploader: user
        )

        expect(adapter).to have_received(:object_exists?)
      end
    end
  end
end
