# frozen_string_literal: true

module DataIntegration
  # Base service for external data integrations.
  # Standardizes initialization and error handling for integration services.
  class BaseService
    def initialize(adapter:)
      @adapter = adapter
    end

    protected

    def handle_integration_error(error)
      Rails.logger.warn("#{service_name} check failed: #{error.message}")
      nil
    end

    def service_name
      self.class.name.demodulize
    end
  end
end
