# frozen_string_literal: true

class DocumentStagingService
  class ValidationError < StandardError; end

  MAX_FILES = 10

  def initialize(doc_ai_service: DocAiService.new)
    @doc_ai_service = doc_ai_service
  end

  def submit(signed_ids:, user:)
    validate_file_count!(signed_ids)

    staged_documents = signed_ids.map do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      staged = StagedDocument.create!(user_id: user.id, status: :pending, file: blob)
      submit_to_doc_ai(staged)
      staged
    end

    pending_ids = staged_documents.select(&:pending?).map(&:id)
    if pending_ids.any?
      FetchDocAiResultsJob.set(wait: 1.minute).perform_later(pending_ids)
    end

    staged_documents
  end

  def fetch_results(staged_document_ids:)
    pending_docs = StagedDocument.where(id: staged_document_ids, status: :pending)
    still_pending_ids = []

    pending_docs.find_each do |staged|
      result = @doc_ai_service.check_status(job_id: staged.doc_ai_job_id)
      update_from_result(staged, result)
      still_pending_ids << staged.id if staged.pending?
    end

    still_pending_ids
  end

  private

  def recognized_document_classes
    DocAiResult::REGISTRY.keys
  end

  def validate_file_count!(signed_ids)
    raise ValidationError, "At least one file is required" if signed_ids.blank?
    raise ValidationError, "A maximum of #{MAX_FILES} files is allowed" if signed_ids.size > MAX_FILES
  end

  def submit_to_doc_ai(staged)
    response = @doc_ai_service.analyze_async(file: staged.file)
    if response.nil?
      staged.update!(status: :failed)
    else
      staged.update!(doc_ai_job_id: response["jobId"])
    end
  end

  def update_from_result(staged, result)
    if result.nil?
      staged.update!(status: :failed)
    elsif result.is_a?(DocAiResult)
      if recognized_document_classes.include?(result.matched_document_class)
        staged.update!(
          status: :validated,
          doc_ai_matched_class: result.matched_document_class,
          extracted_fields: result.fields,
          validated_at: Time.current
        )
      else
        staged.update!(status: :rejected)
      end
    end
    # If result is a Hash (still processing), leave as pending
  end
end
