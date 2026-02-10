# frozen_string_literal: true

require "rails_helper"

RSpec.describe OidcClient, type: :service do
  let(:config) { mock_oidc_config }
  let(:client) { described_class.new(config: config) }

  before do
    stub_oidc_discovery
  end

  describe "#enabled?" do
    context "when SSO is enabled" do
      let(:config) { mock_oidc_config(enabled: true) }

      it "returns true" do
        expect(client.enabled?).to be true
      end
    end

    context "when SSO is disabled" do
      let(:config) { mock_oidc_config(enabled: false) }

      it "returns false" do
        expect(client.enabled?).to be false
      end
    end
  end

  describe "#authorization_url" do
    subject(:url) { client.authorization_url(state: state, nonce: nonce) }

    let(:state) { "test-state-token" }
    let(:nonce) { "test-nonce-token" }

    it "returns a URL to the IdP authorization endpoint" do
      expect(url).to start_with("https://test-idp.example.com/authorize?")
    end

    it "includes the client_id" do
      expect(url).to include("client_id=test-client-id")
    end

    it "includes the redirect_uri" do
      expect(url).to include("redirect_uri=#{CGI.escape('http://localhost:3000/auth/sso/callback')}")
    end

    it "includes the requested scopes" do
      expect(url).to include("scope=openid+profile+email+groups")
    end

    it "includes the state parameter" do
      expect(url).to include("state=test-state-token")
    end

    it "includes the nonce parameter" do
      expect(url).to include("nonce=test-nonce-token")
    end

    it "includes response_type=code" do
      expect(url).to include("response_type=code")
    end
  end

  describe "#exchange_code" do
    let(:code) { "test-authorization-code" }
    let(:claims) { mock_id_token_claims }

    context "when token exchange succeeds" do
      before do
        stub_oidc_token_exchange(claims: claims)
      end

      it "returns the token response" do
        result = client.exchange_code(code: code)

        expect(result).to include(
          "access_token" => "test-access-token",
          "id_token" => be_a(String),
          "token_type" => "Bearer"
        )
      end

      it "sends correct parameters to token endpoint" do
        client.exchange_code(code: code)

        expect(WebMock).to have_requested(:post, "https://test-idp.example.com/token")
          .with(
            body: hash_including(
              "grant_type" => "authorization_code",
              "code" => code,
              "client_id" => "test-client-id",
              "client_secret" => "test-client-secret",
              "redirect_uri" => "http://localhost:3000/auth/sso/callback"
            )
          )
      end
    end

    context "when token exchange fails" do
      before do
        stub_oidc_token_exchange_failure(
          error: "invalid_grant",
          description: "Authorization code expired"
        )
      end

      it "raises TokenExchangeError with the error description" do
        expect { client.exchange_code(code: code) }
          .to raise_error(OidcClient::TokenExchangeError, "Authorization code expired")
      end
    end

    context "when network error occurs" do
      before do
        stub_request(:post, "https://test-idp.example.com/token")
          .to_timeout
      end

      it "raises TokenExchangeError with network error message" do
        expect { client.exchange_code(code: code) }
          .to raise_error(OidcClient::TokenExchangeError, /Network error/)
      end
    end
  end

  describe "#validate_token" do
    let(:claims) { mock_id_token_claims }
    let(:id_token) { create_test_jwt(claims) }

    context "with a valid token" do
      it "returns the decoded claims" do
        result = client.validate_token(id_token)

        expect(result).to include(
          "sub" => "user-123",
          "email" => "staff@example.gov",
          "name" => "Jane Doe"
        )
      end
    end

    context "when token has invalid format" do
      let(:id_token) { "not-a-valid-jwt" }

      it "raises TokenValidationError" do
        expect { client.validate_token(id_token) }
          .to raise_error(OidcClient::TokenValidationError, /Invalid token format/)
      end
    end

    context "when issuer does not match" do
      let(:claims) { mock_id_token_claims("iss" => "https://wrong-issuer.com") }

      it "raises TokenValidationError with issuer mismatch" do
        expect { client.validate_token(id_token) }
          .to raise_error(OidcClient::TokenValidationError, /Invalid issuer/)
      end
    end

    context "when audience does not match" do
      let(:claims) { mock_id_token_claims("aud" => "wrong-client-id") }

      it "raises TokenValidationError with audience mismatch" do
        expect { client.validate_token(id_token) }
          .to raise_error(OidcClient::TokenValidationError, /Invalid audience/)
      end
    end

    context "when audience is an array containing the client_id" do
      let(:claims) { mock_id_token_claims("aud" => [ "other-app", "test-client-id" ]) }

      it "validates successfully" do
        expect { client.validate_token(id_token) }.not_to raise_error
      end
    end

    context "when token is expired" do
      let(:claims) { mock_id_token_claims("exp" => 1.hour.ago.to_i) }

      it "raises TokenValidationError with expiry message" do
        expect { client.validate_token(id_token) }
          .to raise_error(OidcClient::TokenValidationError, /Token expired/)
      end
    end

    context "when token is missing expiry" do
      let(:claims) { mock_id_token_claims.except("exp") }

      it "raises TokenValidationError" do
        expect { client.validate_token(id_token) }
          .to raise_error(OidcClient::TokenValidationError, /missing expiry/)
      end
    end
  end

  describe "#extract_claims" do
    let(:claims) { mock_id_token_claims }
    let(:id_token) { create_test_jwt(claims) }

    it "extracts uid from the configured claim" do
      result = client.extract_claims(id_token)
      expect(result[:uid]).to eq("user-123")
    end

    it "extracts email from the configured claim" do
      result = client.extract_claims(id_token)
      expect(result[:email]).to eq("staff@example.gov")
    end

    it "extracts name from the configured claim" do
      result = client.extract_claims(id_token)
      expect(result[:name]).to eq("Jane Doe")
    end

    it "extracts groups as an array" do
      result = client.extract_claims(id_token)
      expect(result[:groups]).to eq([ "OSCER-Caseworker" ])
    end

    context "when groups claim is missing" do
      let(:claims) { mock_id_token_claims.except("groups") }

      it "returns an empty array for groups" do
        result = client.extract_claims(id_token)
        expect(result[:groups]).to eq([])
      end
    end

    context "when groups is a single string" do
      let(:claims) { mock_id_token_claims("groups" => "OSCER-Admin") }

      it "wraps it in an array" do
        result = client.extract_claims(id_token)
        expect(result[:groups]).to eq([ "OSCER-Admin" ])
      end
    end

    context "with custom claim names" do
      let(:config) do
        mock_oidc_config(
          claims: {
            email: "preferred_email",
            name: "display_name",
            groups: "roles",
            unique_id: "user_id"
          }
        )
      end

      let(:claims) do
        mock_id_token_claims(
          "user_id" => "custom-uid",
          "preferred_email" => "custom@example.com",
          "display_name" => "Custom Name",
          "roles" => [ "CustomRole" ]
        )
      end

      it "uses the configured claim names" do
        result = client.extract_claims(id_token)

        expect(result).to include(
          uid: "custom-uid",
          email: "custom@example.com",
          name: "Custom Name",
          groups: [ "CustomRole" ]
        )
      end
    end

    context "with nonce validation" do
      let(:expected_nonce) { "expected-nonce-value" }
      let(:claims) { mock_id_token_claims("nonce" => expected_nonce) }

      it "validates successfully when nonce matches" do
        expect {
          client.extract_claims(id_token, expected_nonce: expected_nonce)
        }.not_to raise_error
      end

      it "raises error when nonce does not match" do
        expect {
          client.extract_claims(id_token, expected_nonce: "wrong-nonce")
        }.to raise_error(OidcClient::TokenValidationError, /Invalid nonce/)
      end

      it "raises error when token is missing nonce but expected" do
        claims_without_nonce = mock_id_token_claims.except("nonce")
        token_without_nonce = create_test_jwt(claims_without_nonce)

        expect {
          client.extract_claims(token_without_nonce, expected_nonce: expected_nonce)
        }.to raise_error(OidcClient::TokenValidationError, /Invalid nonce/)
      end

      it "skips nonce validation when expected_nonce is nil" do
        expect {
          client.extract_claims(id_token, expected_nonce: nil)
        }.not_to raise_error
      end

      it "skips nonce validation when expected_nonce is not provided" do
        expect {
          client.extract_claims(id_token)
        }.not_to raise_error
      end
    end
  end

  describe "configuration validation" do
    context "when SSO is enabled but config is missing" do
      let(:config) do
        {
          enabled: true,
          issuer: nil,
          client_id: nil,
          client_secret: nil,
          redirect_uri: nil,
          scopes: %w[openid],
          claims: { email: "email", name: "name", groups: "groups", unique_id: "sub" }
        }
      end

      it "raises ConfigurationError listing missing values" do
        expect { client }
          .to raise_error(OidcClient::ConfigurationError, /SSO_ISSUER_URL.*SSO_CLIENT_ID.*SSO_CLIENT_SECRET.*SSO_REDIRECT_URI/)
      end
    end

    context "when SSO is disabled and config is missing" do
      let(:config) do
        {
          enabled: false,
          issuer: nil,
          client_id: nil,
          client_secret: nil,
          redirect_uri: nil,
          scopes: %w[openid],
          claims: { email: "email", name: "name", groups: "groups", unique_id: "sub" }
        }
      end

      it "does not raise an error" do
        expect { client }.not_to raise_error
      end
    end
  end
end
