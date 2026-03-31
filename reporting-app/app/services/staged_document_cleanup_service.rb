# frozen_string_literal: true

# Deletes orphaned StagedDocuments (no stageable) past the configured retention.
# Invoked by +rake doc_ai:cleanup_staged_documents+ and +CleanupStagedDocumentsJob+.
class StagedDocumentCleanupService
  Result = Data.define(:deleted_count, :bytes_freed, :dry_run)

  def self.call(dry_run: false)
    new(dry_run:).call
  end

  def initialize(dry_run:)
    @dry_run = dry_run
    @config = Rails.application.config.doc_ai
  end

  def call
    unless @config[:staged_document_cleanup_enabled]
      log_both("StagedDocument cleanup skipped (STAGED_DOCUMENT_CLEANUP_ENABLED is false)")
      return Result.new(deleted_count: 0, bytes_freed: 0, dry_run: @dry_run)
    end

    deleted_count = 0
    bytes_freed = 0

    orphaned_stale_scope.find_each do |doc|
      bytes = byte_size_for(doc)
      if @dry_run
        deleted_count += 1
        bytes_freed += bytes
        next
      end

      doc.file.purge if doc.file.attached?
      doc.destroy!
      deleted_count += 1
      bytes_freed += bytes
    end

    message = format_message(deleted_count, bytes_freed)
    log_both(message)

    Result.new(deleted_count:, bytes_freed:, dry_run: @dry_run)
  end

  private

  def orphaned_stale_scope
    cutoff = @config[:staged_document_retention_days].days.ago
    StagedDocument.where(stageable_type: nil).where(created_at: ...cutoff)
  end

  def byte_size_for(doc)
    return 0 unless doc.file.attached?

    doc.file.blob.byte_size
  end

  def format_message(count, bytes)
    size = ApplicationController.helpers.number_to_human_size(bytes)
    prefix = @dry_run ? "[dry-run] Would delete" : "Deleted"
    "#{prefix} #{count} staged document(s); approximate storage freed: #{size}"
  end

  def log_both(message)
    puts message
    Rails.logger.info(message)
  end
end
