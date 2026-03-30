# frozen_string_literal: true

namespace :doc_ai do
  desc "Delete orphaned StagedDocuments older than retention (see config/initializers/doc_ai.rb). Pass -- --dry-run to preview without deleting."
  task cleanup_staged_documents: :environment do
    dry_run = ARGV.include?("--dry-run")
    StagedDocumentCleanupService.call(dry_run: dry_run)
  end
end
