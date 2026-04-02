# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchDocAiResultsJob, type: :job do
  let(:user) { create(:user) }
  let(:staged_doc) { create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending") }
  let(:service) { instance_double(DocumentStagingService) }

  let(:batch_key) { Digest::SHA256.hexdigest([ staged_doc.id ].sort.join(",")) }

  before do
    allow(DocumentStagingService).to receive(:new).and_return(service)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
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

      it "broadcasts completion to the batch stream" do
        described_class.perform_now([ staged_doc.id ])
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
          "document_staging_batch_#{batch_key}",
          target: "document_staging_status",
          partial: "document_staging/results",
          locals: { staged_documents: anything }
        )
      end

      context "when all documents are validated" do
        let(:staged_doc) { create(:staged_document, :validated, user_id: user.id) }

        it "broadcasts upload notification with all_validated: true" do
          described_class.perform_now([ staged_doc.id ])
          expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
            "document_staging_batch_#{batch_key}",
            target: "flash-messages",
            partial: "document_staging/upload_notification",
            locals: { all_validated: true }
          )
        end
      end

      context "when any document is not validated" do
        let(:staged_doc) { create(:staged_document, :rejected, user_id: user.id) }

        it "broadcasts upload notification with all_validated: false" do
          described_class.perform_now([ staged_doc.id ])
          expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
            "document_staging_batch_#{batch_key}",
            target: "flash-messages",
            partial: "document_staging/upload_notification",
            locals: { all_validated: false }
          )
        end
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

      it "does not broadcast" do
        described_class.perform_now([ staged_doc.id ], attempt: 1)
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
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

      it "broadcasts completion to the batch stream" do
        described_class.perform_now([ staged_doc.id ], attempt: 5)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
          "document_staging_batch_#{batch_key}",
          target: "document_staging_status",
          partial: "document_staging/results",
          locals: { staged_documents: anything }
        )
      end

      it "broadcasts upload notification with all_validated: false" do
        described_class.perform_now([ staged_doc.id ], attempt: 5)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
          "document_staging_batch_#{batch_key}",
          target: "flash-messages",
          partial: "document_staging/upload_notification",
          locals: { all_validated: false }
        )
      end
    end
  end
end
