# frozen_string_literal: true

require "rails_helper"

RSpec.describe Verification::Adapters::VaDisabilityRating do
  let(:adapter) { instance_double(VeteranAffairsAdapter) }
  let(:token_manager) { instance_double(VaTokenManager) }
  let(:data_source) { described_class.new(adapter: adapter, token_manager: token_manager) }
  let(:icn) { "1012861229V078999" }
  let(:access_token) { "test-token" }
  let(:certification) { build(:certification, member_data: build(:certification_member_data, va_icn: icn)) }

  def rating_response(combined_rating)
    {
      "data" => {
        "id" => "12303",
        "type" => "disability-rating",
        "attributes" => {
          "combined_disability_rating" => combined_rating,
          "individual_ratings" => [
            { "decision" => "Service Connected", "rating_percentage" => combined_rating }
          ]
        }
      }
    }
  end

  describe ".declared_outcomes" do
    it "declares the single VA outcome symbol" do
      expect(described_class.declared_outcomes).to eq([ :is_veteran_with_disability ])
    end
  end

  describe "#call" do
    subject(:result) { data_source.call(certification: certification) }

    before do
      allow(token_manager).to receive(:get_access_token).with(icn: icn).and_return(access_token)
      allow(adapter).to receive(:get_disability_rating).with(access_token: access_token).and_return(rating_data)
    end

    context "when the combined rating is 100 (qualifying)" do
      let(:rating_data) { rating_response(100) }

      it_behaves_like "a successful verification result"

      it "emits :is_veteran_with_disability" do
        expect(result.outcomes).to eq([ :is_veteran_with_disability ])
      end

      it "records a redacted audit summary (no full payload)" do
        expect(result.audit_data).to eq(
          source: "va_disability_rating",
          combined_disability_rating: 100,
          disability_rating_id: "12303"
        )
        expect(result.audit_data).not_to have_key(:individual_ratings)
      end
    end

    context "when the combined rating is below 100 (no match)" do
      let(:rating_data) { rating_response(70) }

      it_behaves_like "a successful verification result"

      it "returns success with empty outcomes" do
        expect(result.outcomes).to eq([])
      end

      it "still records the observed rating in audit_data" do
        expect(result.audit_data[:combined_disability_rating]).to eq(70)
      end
    end

    context "when the VA payload has no combined rating" do
      let(:rating_data) { { "data" => { "id" => "12303", "attributes" => {} } } }

      it_behaves_like "a successful verification result"

      it "returns success with empty outcomes" do
        expect(result.outcomes).to eq([])
      end
    end
  end

  describe "#call when the ICN precondition is missing" do
    subject(:result) { data_source.call(certification: certification) }

    let(:certification) { build(:certification, member_data: build(:certification_member_data, va_icn: nil)) }

    it_behaves_like "a skipped verification result"

    it "does not call the token manager or transport adapter" do
      allow(token_manager).to receive(:get_access_token)
      allow(adapter).to receive(:get_disability_rating)

      result

      expect(token_manager).not_to have_received(:get_access_token)
      expect(adapter).not_to have_received(:get_disability_rating)
    end
  end

  describe "#call when the transport layer fails" do
    subject(:result) { data_source.call(certification: certification) }

    context "when the adapter raises an ApiError" do
      before do
        allow(token_manager).to receive(:get_access_token).with(icn: icn).and_return(access_token)
        allow(adapter).to receive(:get_disability_rating)
          .and_raise(VeteranAffairsAdapter::ApiError.new("VA API server error: 500"))
      end

      it_behaves_like "an errored verification result"
      it_behaves_like "a resilient verification data source"

      it "records the error and a source-tagged audit_data" do
        expect(result.error_code).to eq(:api_error)
        expect(result.error_message).to eq("VA API server error: 500")
        expect(result.audit_data).to eq(source: "va_disability_rating")
      end
    end

    context "when the token manager raises a TokenError" do
      before do
        allow(token_manager).to receive(:get_access_token)
          .and_raise(VaTokenManager::TokenError.new("Auth failed"))
        allow(adapter).to receive(:get_disability_rating)
      end

      it_behaves_like "an errored verification result"
      it_behaves_like "a resilient verification data source"

      it "does not attempt the disability-rating request" do
        result

        expect(adapter).not_to have_received(:get_disability_rating)
      end
    end
  end
end
