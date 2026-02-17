# frozen_string_literal: true

class VeteranDisabilityService < DataIntegration::BaseService
  def initialize(adapter: VeteranAffairsAdapter.new, token_manager: VaTokenManager.new)
    super(adapter: adapter)
    @token_manager = token_manager
  end

  def get_disability_rating(icn:)
    access_token = @token_manager.get_access_token(icn: icn)
    @adapter.get_disability_rating(access_token: access_token)
  rescue VeteranAffairsAdapter::ApiError, VaTokenManager::TokenError => e
    handle_integration_error(e)
  end

  private

  def service_name
    "VA API"
  end
end
