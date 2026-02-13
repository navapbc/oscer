# frozen_string_literal: true

class VeteranDisabilityService
  def initialize(adapter: VeteranAffairsAdapter.new, token_manager: VaTokenManager.new)
    @adapter = adapter
    @token_manager = token_manager
  end

  def get_disability_rating(icn:)
    access_token = @token_manager.get_access_token(icn: icn)
    @adapter.get_disability_rating(access_token: access_token)
  rescue VeteranAffairsAdapter::ApiError, VaTokenManager::TokenError => e
    Rails.logger.warn("VA API check failed: #{e.message}")
    nil
  end
end
