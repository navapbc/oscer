# frozen_string_literal: true

# Scheduled via GoodJob cron (see config/initializers/good_job.rb). Also runnable via
# +rake doc_ai:cleanup_staged_documents+ for manual or host-level cron.
class CleanupStagedDocumentsJob < ApplicationJob
  def perform
    StagedDocumentCleanupService.call(dry_run: false)
  end
end
