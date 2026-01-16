# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiAuthenticator do
  let(:service) { described_class.new }
  let(:secret) { "test_secret_key_12345678901234567890" }
  let(:body) { { "member_id" => "123", "hours" => 80 }.to_json }

  before do
    allow(ENV).to receive(:fetch).with("API_SECRET_KEY").and_return(secret)
  end

  describe "#authenticate!" do
    context "with valid signature" do
      it "returns true" do
        headers = api_auth_headers(body: body, secret: secret)
        request = mock_api_request(body: body, headers: headers)

        expect(service.authenticate!(request)).to be true
      end
    end

    context "with missing Authorization header" do
      it "raises MissingCredentials error" do
        request = mock_api_request(body: body, headers: {})

        expect { service.authenticate!(request) }.to raise_error(ApiAuthenticator::MissingCredentials)
      end
    end

    context "with malformed Authorization header" do
      it "raises MissingCredentials error" do
        headers = { "Authorization" => "HMAC sig=" }
        request = mock_api_request(body: body, headers: headers)

        expect { service.authenticate!(request) }.to raise_error(ApiAuthenticator::MissingCredentials)
      end
    end

    context "with invalid signature" do
      it "raises InvalidSignature error" do
        headers = api_auth_headers(body: body, secret: "wrong_secret")
        request = mock_api_request(body: body, headers: headers)

        # binding.break

        expect { service.authenticate!(request) }.to raise_error(ApiAuthenticator::InvalidSignature)
      end
    end

    context "with tampered body" do
      it "raises InvalidSignature error" do
        headers = api_auth_headers(body: body, secret: secret)
        request = mock_api_request(body: "tampered body", headers: headers)

        expect { service.authenticate!(request) }.to raise_error(ApiAuthenticator::InvalidSignature)
      end
    end
  end

  describe "#sign" do
    it "generates a base64 encoded HMAC-SHA256 signature" do
      signature = service.sign(body: body)
      expect(signature).to be_a(String)
      expect { Base64.strict_decode64(signature) }.not_to raise_error
    end

    it "matches manual signature generation" do
      manual_sig = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", secret, body))
      expect(service.sign(body: body)).to eq(manual_sig)
    end
  end
end
