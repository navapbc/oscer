# frozen_string_literal: true

require "rails_helper"

RSpec.describe VaTokenManager do
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:config) do
    {
      client_id_ccg: "test-client-id",
      private_key: private_key.to_pem,
      audience: "https://fake-va.gov/oauth2/token",
      token_host: "https://fake-va.gov/host"
    }
  end
  let(:token_manager) { described_class.new(config: config) }
  let(:icn) { "12345V67890" }

  describe "#get_access_token" do
    let(:token_response) do
      {
        "access_token" => "new-access-token",
        "expires_in" => 300, # 5 minutes
        "token_type" => "Bearer"
      }
    end

    context "when no token is cached for the ICN" do
      before do
        stub_request(:post, config[:token_host])
          .to_return(status: 200, body: token_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "fetches a new token and caches it" do
        token = token_manager.get_access_token(icn: icn)
        expect(token).to eq("new-access-token")

        expect(WebMock).to have_requested(:post, config[:token_host])
          .with { |req|
            body = URI.decode_www_form(req.body).to_h
            expect(body["grant_type"]).to eq("client_credentials")
            expect(body["scope"]).to eq("disability_rating.read launch")

            # Verify launch parameter is Base64 encoded patient ICN
            launch = JSON.parse(Base64.strict_decode64(body["launch"]))
            expect(launch["patient"]).to eq(icn)

            # Verify client_assertion is a valid JWT
            jwt = JWT.decode(body["client_assertion"], private_key.public_key, true, { algorithm: "RS256" })[0]
            expect(jwt["iss"]).to eq(config[:client_id_ccg])
            expect(jwt["sub"]).to eq(config[:client_id_ccg])
            expect(jwt["aud"]).to eq(config[:audience])
            expect(jwt["exp"]).to be_within(1.second).of(Time.current.to_i + 300)
            true
          }
      end
    end

    context "when a valid token is already cached for the ICN" do
      before do
        stub_request(:post, config[:token_host])
          .to_return(status: 200, body: token_response.to_json, headers: { "Content-Type" => "application/json" })

        # First call to populate cache
        token_manager.get_access_token(icn: icn)
      end

      it "returns the cached token without making a new request" do
        token = token_manager.get_access_token(icn: icn)
        expect(token).to eq("new-access-token")
        expect(WebMock).to have_requested(:post, config[:token_host]).once
      end
    end

    context "when the cached token is expired" do
      before do
        stub_request(:post, config[:token_host])
          .to_return(
            { status: 200, body: token_response.merge("access_token" => "old-token", "expires_in" => 10).to_json },
            { status: 200, body: token_response.merge("access_token" => "new-token").to_json }
          )

        # First call to populate cache
        token_manager.get_access_token(icn: icn)

        # Travel to future where token is expired (using 30s buffer)
        travel_to(Time.current + 60)
      end

      after do
        travel_back
      end

      it "refreshes the token" do
        token = token_manager.get_access_token(icn: icn)
        expect(token).to eq("new-token")
        expect(WebMock).to have_requested(:post, config[:token_host]).twice
      end
    end

    context "when token exchange fails" do
      before do
        stub_request(:post, config[:token_host]).to_return(status: 400, body: '{"error": "invalid_client"}')
      end

      it "raises a TokenError" do
        expect { token_manager.get_access_token(icn: icn) }
          .to raise_error(VaTokenManager::TokenError, /invalid_client/)
      end
    end
  end
end
