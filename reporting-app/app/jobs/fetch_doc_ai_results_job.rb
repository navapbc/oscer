# frozen_string_literal: true

class FetchDocAiResultsJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  MAX_ATTEMPTS = 5

  def perform(staged_document_ids, attempt: 1)
    still_pending_ids = DocumentStagingService.new.fetch_results(staged_document_ids: staged_document_ids)

    return if still_pending_ids.empty?

    if attempt >= MAX_ATTEMPTS
      StagedDocument.where(id: still_pending_ids, status: :pending).update_all(status: :failed) # rubocop:disable Rails/SkipsModelValidations
    else
      self.class.set(wait: 30.seconds).perform_later(still_pending_ids, attempt: attempt + 1)
    end
  end
end
