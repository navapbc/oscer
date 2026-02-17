# frozen_string_literal: true

module DataIntegration
  # Base adapter for external data integrations.
  # Handles common HTTP concerns like connection setup, and error handling.
  class BaseAdapter
    class ApiError < StandardError; end
    class UnauthorizedError < ApiError; end
    class ServerError < ApiError; end
    class RateLimitError < ApiError; end

    def initialize(connection: nil)
      @connection = connection || default_connection
    end

    protected

    def default_connection
      raise NotImplementedError, "#{self.class} must implement #default_connection"
    end

    def handle_unauthorized(response)
      raise UnauthorizedError, "#{adapter_name} unauthorized"
    end

    def handle_rate_limit(response)
      raise RateLimitError, "#{adapter_name} rate limited"
    end

    def handle_server_error(response)
      raise ServerError, "#{adapter_name} server error: #{response.status}"
    end

    def handle_error(response)
      raise ApiError, "#{adapter_name} error: #{response.status}"
    end

    def handle_connection_error(e)
      raise ApiError, "#{adapter_name} connection error: #{e.message}"
    end

    def adapter_name
      self.class.name.demodulize
    end

    private

    def with_error_handling
      response = yield

      case response.status
      when 200..299
        response.body
      when 401
        handle_unauthorized(response)
      when 429
        handle_rate_limit(response)
      when 500..599
        handle_server_error(response)
      else
        handle_error(response)
      end
    rescue Faraday::Error => e
      handle_connection_error(e)
    end
  end
end
