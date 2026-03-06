# frozen_string_literal: true

class DocAiAdapter < DataIntegration::BaseAdapter
  def analyze_document(file:)
    file.blob.open do |tempfile|
      with_error_handling do
        @connection.post("v1/documents") do |req|
          req.params["wait"] = true
          req.body = { file: Faraday::Multipart::FilePart.new(tempfile, file.content_type, file.filename.to_s) }
        end
      end
    end
  end

  def analyze_document_async(file:)
    file.blob.open do |tempfile|
      with_error_handling do
        @connection.post("v1/documents") do |req|
          req.body = { file: Faraday::Multipart::FilePart.new(tempfile, file.content_type, file.filename.to_s) }
        end
      end
    end
  end

  def get_document_status(job_id:)
    with_error_handling do
      @connection.get("v1/documents/#{job_id}")
    end
  end

  def handle_error(response)
    detail = response.body.is_a?(Hash) ? response.body["detail"] : nil
    raise ApiError, detail || "DocAI error: #{response.status}"
  end

  private

  def default_connection
    Faraday.new(url: Rails.application.config.doc_ai[:api_host]) do |f|
      f.request :multipart
      f.request :url_encoded
      f.response :json
      f.adapter Faraday.default_adapter
      f.options.open_timeout = 10
      f.options.timeout      = Rails.application.config.doc_ai[:timeout_seconds]
    end
  end
end
