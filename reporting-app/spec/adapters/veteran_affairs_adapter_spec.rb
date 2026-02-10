# frozen_string_literal: true

require "rails_helper"

RSpec.describe VeteranAffairsAdapter do
  let(:api_host) { "https://sandbox-api.va.gov" }
  let(:connection) { Faraday.new(url: api_host) }
  let(:adapter) { described_class.new(connection: connection) }
  let(:access_token) { "test-access-token" }

  describe "#get_disability_rating" do
    let(:endpoint) { "#{api_host}/services/veteran_verification/v2/disability_rating" }
    let(:response_body) do
      {
        "data" => {
          "id" => "12303",
          "type" => "disability-rating",
          "attributes" => {
            "combined_disability_rating" => 100,
            "combined_effective_date" => "2018-03-27",
            "legal_effective_date" => "2018-03-27",
            "individual_ratings" => [
              {
                "decision" => "Service Connected",
                "disability_rating_id" => "1070379",
                "effective_date" => "2018-03-27",
                "rating_end_date" => "2022-08-27",
                "rating_percentage" => 50,
                "static_ind" => true
              }
            ]
          }
        }
      }
    end

    context "when the request is successful" do
      before do
        stub_request(:get, endpoint)
          .with(headers: { "Authorization" => "Bearer #{access_token}" })
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns the parsed response body" do
        expect(adapter.get_disability_rating(access_token: access_token)).to eq(response_body.to_json)
      end
    end

    context "when the request is unauthorized (401)" do
      before do
        stub_request(:get, endpoint).to_return(status: 401)
      end

      it "raises an UnauthorizedError" do
        expect { adapter.get_disability_rating(access_token: access_token) }
          .to raise_error(VeteranAffairsAdapter::UnauthorizedError)
      end
    end

    context "when the request is rate limited (429)" do
      before do
        stub_request(:get, endpoint).to_return(
          status: 429,
          headers: { "ratelimit-reset" => "30" }
        )
      end

      it "raises a RateLimitError" do
        expect { adapter.get_disability_rating(access_token: access_token) }
          .to raise_error(VeteranAffairsAdapter::RateLimitError, /VA API rate limited. Reset in 30s/)
      end
    end

    context "when the server returns an error (500)" do
      before do
        stub_request(:get, endpoint).to_return(status: 500)
      end

      it "raises a ServerError" do
        expect { adapter.get_disability_rating(access_token: access_token) }
          .to raise_error(VeteranAffairsAdapter::ServerError)
      end
    end

    context "when a network error occurs" do
      before do
        stub_request(:get, endpoint).to_timeout
      end

      it "raises an ApiError" do
        expect { adapter.get_disability_rating(access_token: access_token) }
          .to raise_error(VeteranAffairsAdapter::ApiError)
      end
    end

    describe "rate limit logging" do
      it "logs a warning when ratelimit-remaining is low" do
        allow(Rails.logger).to receive(:warn)
        stub_request(:get, endpoint).to_return(
          status: 200,
          body: response_body.to_json,
          headers: { "ratelimit-remaining" => "5" }
        )

        adapter.get_disability_rating(access_token: access_token)
        expect(Rails.logger).to have_received(:warn).with(/VA API rate limit low: 5 remaining/)
      end
    end
  end
end
