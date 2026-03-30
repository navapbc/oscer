# frozen_string_literal: true

class FetchDocAiResultsJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  MAX_ATTEMPTS = 5

  def perform(staged_document_ids, attempt: 1)
    still_pending_ids = DocumentStagingService.new.fetch_results(staged_document_ids: staged_document_ids)

    if still_pending_ids.empty?
      broadcast_completion(staged_document_ids)
      return
    end

    if attempt >= MAX_ATTEMPTS
      StagedDocument.where(id: still_pending_ids, status: :pending).update_all(status: :failed) # rubocop:disable Rails/SkipsModelValidations
      broadcast_completion(staged_document_ids)
    else
      self.class.set(wait: 30.seconds).perform_later(still_pending_ids, attempt: attempt + 1)
    end
  end

  private

  def broadcast_completion(staged_document_ids)
    batch_key = Digest::SHA256.hexdigest(staged_document_ids.sort.join(","))
    staged_documents = StagedDocument.where(id: staged_document_ids)
    Turbo::StreamsChannel.broadcast_replace_to(
      "document_staging_batch_#{batch_key}",
      target: "document_staging_status",
      partial: "document_staging/results",
      locals: { staged_documents: staged_documents, all_complete: true }
    )
  end
end
