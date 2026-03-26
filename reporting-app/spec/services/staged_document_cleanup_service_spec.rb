# frozen_string_literal: true

require "rails_helper"

RSpec.describe StagedDocumentCleanupService do
  def with_doc_ai_config(overrides)
    merged = Rails.application.config.doc_ai.merge(overrides)
    allow(Rails.application.config).to receive(:doc_ai).and_return(merged)
  end

  describe ".call" do
    context "when STAGED_DOCUMENT_CLEANUP_ENABLED is false" do
      before { with_doc_ai_config(staged_document_cleanup_enabled: false) }

      it "does not delete staged documents and logs skip" do
        create(:staged_document, created_at: 10.days.ago)
        allow(Rails.logger).to receive(:info)

        expect do
          described_class.call(dry_run: false)
        end.not_to change(StagedDocument, :count)

        expect(Rails.logger).to have_received(:info).with(/skipped/)
      end
    end

    context "when cleanup is enabled" do
      before { with_doc_ai_config(staged_document_cleanup_enabled: true, staged_document_retention_days: 7) }

      it "dry_run does not remove records or blobs" do
        doc = create(:staged_document, :validated, created_at: 10.days.ago)
        blob_id = doc.file.blob.id

        expect do
          described_class.call(dry_run: true)
        end.not_to change(StagedDocument, :count)

        expect(ActiveStorage::Blob.exists?(blob_id)).to be true
      end

      it "deletes unattached documents older than retention and purges storage" do
        old = create(:staged_document, :rejected, created_at: 10.days.ago)
        blob_id = old.file.blob.id

        expect do
          described_class.call(dry_run: false)
        end.to change(StagedDocument, :count).by(-1)

        expect(StagedDocument.find_by(id: old.id)).to be_nil
        expect(ActiveStorage::Blob.exists?(blob_id)).to be false
      end

      it "does not delete unattached documents within the retention window" do
        create(:staged_document, created_at: 6.days.ago)

        expect do
          described_class.call(dry_run: false)
        end.not_to change(StagedDocument, :count)
      end

      it "does not delete staged documents attached to an activity" do
        form = create(:activity_report_application_form, user_id: create(:user).id)
        activity = form.activities.create!(
          name: "Employer",
          type: "IncomeActivity",
          income: 200_000,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
        create(:staged_document, :validated,
          stageable: activity,
          created_at: 10.days.ago,
          user_id: create(:user).id)

        expect do
          described_class.call(dry_run: false)
        end.not_to change(StagedDocument, :count)
      end

      it "deletes failed-status orphans past retention" do
        create(:staged_document, :failed, created_at: 10.days.ago)

        expect do
          described_class.call(dry_run: false)
        end.to change(StagedDocument, :count).by(-1)
      end
    end
  end
end
