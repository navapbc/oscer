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
end
