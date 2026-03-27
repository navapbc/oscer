# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupStagedDocumentsJob, type: :job do
  describe "#perform" do
    it "delegates to StagedDocumentCleanupService without dry-run" do
      allow(StagedDocumentCleanupService).to receive(:call)

      described_class.perform_now

      expect(StagedDocumentCleanupService).to have_received(:call).with(dry_run: false)
    end
  end
end
