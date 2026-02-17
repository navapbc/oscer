# frozen_string_literal: true

module DataIntegration
  # Base adapter for external data integrations.
  # Handles common HTTP concerns like connection setup, and error handling.
  class BaseAdapter
    class ApiError < StandardError; end
    class UnauthorizedError < ApiError; end
    class ServerError < ApiError; end
    class RateLimitError < ApiError; end

    class << self
      def before_request(method_name)
        before_request_hooks << method_name
      end

      def after_request(method_name)
        after_request_hooks << method_name
      end

      def before_request_hooks
        @before_request_hooks ||= []
      end

      def after_request_hooks
        @after_request_hooks ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@before_request_hooks, before_request_hooks.dup)
        subclass.instance_variable_set(:@after_request_hooks, after_request_hooks.dup)
      end
    end

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
      run_before_request_hooks

      response = yield

      run_after_request_hooks(response)

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

    def run_before_request_hooks
      self.class.before_request_hooks.each do |hook|
        send(hook)
      end
    end

    def run_after_request_hooks(response)
      self.class.after_request_hooks.each do |hook|
        send(hook, response)
      end
    end
  end
end
