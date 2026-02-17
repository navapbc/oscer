# frozen_string_literal: true

class VeteranAffairsAdapter < DataIntegration::BaseAdapter
  after_request :handle_rate_limit_headers

  def get_disability_rating(access_token:)
    with_error_handling do
      @connection.get("services/veteran_verification/v2/disability_rating") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
    end
  end

  private

  def default_connection
    Faraday.new(url: Rails.application.config.veteran_affairs[:api_host]) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def handle_rate_limit(response)
    reset_in = response.headers["ratelimit-reset"]
    raise RateLimitError, "VA API rate limited. Reset in #{reset_in}s"
  end

  def handle_rate_limit_headers(response)
    remaining = response.headers["ratelimit-remaining"]
    return unless remaining.present?

    if remaining.to_i < 10
      Rails.logger.warn("VA API rate limit low: #{remaining} remaining")
    end
  end
end
