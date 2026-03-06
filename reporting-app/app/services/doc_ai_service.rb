# frozen_string_literal: true

class DocAiService < DataIntegration::BaseService
  class ProcessingError < StandardError; end

  def initialize(adapter: DocAiAdapter.new)
    super(adapter: adapter)
  end

  def analyze(file:)
    response = @adapter.analyze_document(file: file)
    result   = DocAiResult.from_response(response)
    raise ProcessingError, result.error if result.failed?

    Rails.logger.info(
      "[DocAiService] job_id=#{result.job_id} status=#{result.status} " \
      "matched_class=#{result.matched_document_class} " \
      "processing_seconds=#{result.total_processing_time_seconds}"
    )
    result
  rescue DocAiAdapter::ApiError, ProcessingError => e
    handle_integration_error(e)
  end

  def analyze_async(file:)
    response = @adapter.analyze_document_async(file: file)
    Rails.logger.info(
      "[DocAiService] Submitted document: job_id=#{response["jobId"]} status=#{response["status"]}"
    )
    response
  rescue DocAiAdapter::ApiError => e
    handle_integration_error(e)
  end

  def check_status(job_id:)
    response = @adapter.get_document_status(job_id: job_id)

    case response["status"]
    when "completed"
      result = DocAiResult.from_response(response)
      raise ProcessingError, result.error if result.failed?

      result
    when "failed"
      raise ProcessingError, response["error"] || "DocAI processing failed"
    else
      response
    end
  rescue DocAiAdapter::ApiError, ProcessingError => e
    handle_integration_error(e)
  end
end
