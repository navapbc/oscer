# frozen_string_literal: true

class VeteranAffairsAdapter
  class ApiError < StandardError; end
  class UnauthorizedError < ApiError; end
  class RateLimitError < ApiError; end
  class ServerError < ApiError; end

  def initialize(connection: nil)
    @connection = connection || default_connection
  end

  def get_disability_rating(access_token:)
    with_rate_limiting do
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

  def with_rate_limiting
    response = yield

    handle_rate_limit_headers(response)

    case response.status
    when 200..299
      response.body
    when 401
      raise UnauthorizedError, "VA API unauthorized"
    when 429
      reset_in = response.headers["ratelimit-reset"]
      raise RateLimitError, "VA API rate limited. Reset in #{reset_in}s"
    when 500..599
      raise ServerError, "VA API server error: #{response.status}"
    else
      raise ApiError, "VA API error: #{response.status}"
    end
  rescue Faraday::Error => e
    raise ApiError, "VA API connection error: #{e.message}"
  end

  def handle_rate_limit_headers(response)
    remaining = response.headers["ratelimit-remaining"]
    return unless remaining.present?

    if remaining.to_i < 10
      Rails.logger.warn("VA API rate limit low: #{remaining} remaining")
    end
  end
end
