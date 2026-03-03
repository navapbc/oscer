# frozen_string_literal: true

# Helper module for SSO functionality in views
module SsoHelper
  # Check if SSO is enabled for the application
  # @return [Boolean] true if SSO is enabled via configuration
  def sso_enabled?
    Rails.application.config.sso[:enabled] == true
  rescue NoMethodError
    # SSO config not loaded (e.g., in tests without SSO setup)
    false
  end
end
