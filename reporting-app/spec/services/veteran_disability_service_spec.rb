# frozen_string_literal: true

require "rails_helper"

RSpec.describe VeteranDisabilityService do
  let(:adapter) { instance_double(VeteranAffairsAdapter) }
  let(:token_manager) { instance_double(VaTokenManager) }
  let(:service) { described_class.new(adapter: adapter, token_manager: token_manager) }
  let(:icn) { "12345V67890" }
  let(:access_token) { "test-token" }

  describe "#get_disability_rating" do
    let(:rating_data) do
      {
        "data" => {
          "attributes" => {
            "combined_disability_rating" => 70,
            "individual_ratings" => [
              { "decision" => "Service Connected", "rating_percentage" => 70 }
            ]
          }
        }
      }
    end

    context "when successful" do
      before do
        allow(token_manager).to receive(:get_access_token).with(icn: icn).and_return(access_token)
        allow(adapter).to receive(:get_disability_rating).with(access_token: access_token).and_return(rating_data)
      end

      it "returns the rating data" do
        expect(service.get_disability_rating(icn: icn)).to eq(rating_data)
      end
    end

    context "when the adapter raises an ApiError (fail-open)" do
      before do
        allow(token_manager).to receive(:get_access_token).with(icn: icn).and_return(access_token)
        allow(adapter).to receive(:get_disability_rating).and_raise(VeteranAffairsAdapter::ApiError.new("API Down"))
      end

      it "returns nil and logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/VA API check failed: API Down/)
        expect(service.get_disability_rating(icn: icn)).to be_nil
      end
    end

    context "when the token manager raises an error (fail-open)" do
      before do
        allow(token_manager).to receive(:get_access_token).and_raise(VaTokenManager::TokenError.new("Auth failed"))
      end

      it "returns nil and logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/VA API check failed: Auth failed/)
        expect(service.get_disability_rating(icn: icn)).to be_nil
      end
    end
  end
end
