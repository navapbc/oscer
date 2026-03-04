# frozen_string_literal: true

# Shared HMAC authentication for API endpoints.
#
# Included by both ApiController (ActionController::Metal) and
# Api::DirectUploadsController (ActionController::Base) since they
# share the same auth logic but can't share a base class.
module ApiHmacAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_api_request!
    strategy = Strata::Auth::Strategies::Hmac.new(secret_key: Rails.configuration.api_secret_key)
    authenticator = Strata::ApiAuthenticator.new(strategy: strategy)

    begin
      authenticator.authenticate!(request)
      @current_api_client = Api::Client.new
    rescue Strata::Auth::AuthenticationError, Strata::Auth::InvalidSignature, Strata::Auth::MissingCredentials => e
      render json: { errors: [ e.message ] }, status: :unauthorized
      false
    end
  end
end
