# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Sso", type: :request do
  include Warden::Test::Helpers

  let(:oidc_config) { mock_oidc_config }

  before do
    allow(Rails.application.config).to receive(:sso).and_return(oidc_config)
  end

  after do
    Warden.test_reset!
  end

  describe "GET /auth/sso" do
    context "when SSO is enabled" do
      it "redirects to the IdP authorization URL" do
        get "/auth/sso"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with("https://test-idp.example.com/authorize")
      end

      it "includes required OAuth parameters" do
        get "/auth/sso"

        location = URI.parse(response.location)
        params = Rack::Utils.parse_query(location.query)

        expect(params["response_type"]).to eq("code")
        expect(params["client_id"]).to eq("test-client-id")
        expect(params["redirect_uri"]).to eq("http://localhost:3000/auth/sso/callback")
        expect(params["scope"]).to include("openid")
        expect(params["state"]).to be_present
        expect(params["nonce"]).to be_present
      end

      it "stores state and nonce in session" do
        get "/auth/sso"

        expect(session[:sso_state]).to be_present
        expect(session[:sso_nonce]).to be_present
      end
    end

    context "when SSO is disabled" do
      let(:oidc_config) { mock_oidc_config(enabled: false) }

      it "redirects to root with error message" do
        get "/auth/sso"

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("SSO is not enabled")
      end
    end

    context "when user is already authenticated" do
      let(:user) { create(:user, :as_admin) }

      before { login_as(user) }

      it "redirects to the appropriate dashboard" do
        get "/auth/sso"

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include("authorize")
      end
    end
  end

  describe "GET /auth/sso/callback" do
    let(:valid_state) { SecureRandom.hex(32) }
    let(:valid_code) { "valid-authorization-code" }

    before do
      # Set up session state (simulating the /auth/sso redirect)
      get "/auth/sso"
      @stored_state = session[:sso_state]
      @stored_nonce = session[:sso_nonce]
    end

    # Helper to create claims with the correct nonce
    def id_token_claims_with_nonce(overrides = {})
      mock_id_token_claims({ "nonce" => @stored_nonce }.merge(overrides))
    end

    context "with valid code and state" do
      before do
        stub_oidc_token_exchange(claims: id_token_claims_with_nonce)
      end

      it "creates a new user session" do
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }

        expect(response).to have_http_status(:redirect)
        expect(controller.current_user).to be_present
      end

      it "provisions a new user from claims" do
        expect {
          get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }
        }.to change(User, :count).by(1)
      end

      it "redirects to the appropriate dashboard" do
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }

        # After sign in, redirects based on MFA preference
        expect(response).to have_http_status(:redirect)
      end

      it "clears SSO session data" do
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }

        expect(session[:sso_state]).to be_nil
        expect(session[:sso_nonce]).to be_nil
      end

      it "finds existing user by UID on subsequent login" do
        # First login creates user
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }
        logout

        # Second login should find existing user
        get "/auth/sso"
        new_state = session[:sso_state]
        new_nonce = session[:sso_nonce]
        stub_oidc_token_exchange(claims: mock_id_token_claims("nonce" => new_nonce))

        expect {
          get "/auth/sso/callback", params: { code: valid_code, state: new_state }
        }.not_to change(User, :count)
      end
    end

    context "with OAuth error from IdP" do
      it "redirects with error when user denies consent" do
        get "/auth/sso/callback", params: {
          error: "access_denied",
          error_description: "User denied consent",
          state: @stored_state
        }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Authentication failed")
      end

      it "does not attempt token exchange" do
        # No stub - if token exchange is called, it will fail
        get "/auth/sso/callback", params: {
          error: "access_denied",
          state: @stored_state
        }

        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid nonce" do
      before do
        # Token has wrong nonce
        stub_oidc_token_exchange(claims: mock_id_token_claims("nonce" => "wrong-nonce"))
      end

      it "redirects with error" do
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Authentication failed")
      end

      it "does not create a user" do
        expect {
          get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }
        }.not_to change(User, :count)
      end
    end

    context "with invalid state parameter" do
      before do
        stub_oidc_token_exchange(claims: id_token_claims_with_nonce)
      end

      it "redirects with error for mismatched state" do
        get "/auth/sso/callback", params: { code: valid_code, state: "wrong-state" }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Authentication failed")
      end

      it "redirects with error for missing state" do
        get "/auth/sso/callback", params: { code: valid_code }

        expect(response).to redirect_to(root_path)
      end

      it "does not create a user" do
        expect {
          get "/auth/sso/callback", params: { code: valid_code, state: "wrong-state" }
        }.not_to change(User, :count)
      end
    end

    context "with invalid authorization code" do
      before do
        stub_oidc_token_exchange_failure
      end

      it "redirects with error message" do
        get "/auth/sso/callback", params: { code: "invalid-code", state: @stored_state }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Authentication failed")
      end

      it "does not create a user" do
        expect {
          get "/auth/sso/callback", params: { code: "invalid-code", state: @stored_state }
        }.not_to change(User, :count)
      end
    end

    context "when user's groups don't match any role" do
      before do
        stub_oidc_token_exchange(claims: id_token_claims_with_nonce("groups" => ["Unknown-Group"]))
      end

      it "redirects with access denied message" do
        get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("do not have permission")
      end

      it "does not create a user" do
        expect {
          get "/auth/sso/callback", params: { code: valid_code, state: @stored_state }
        }.not_to change(User, :count)
      end
    end

    context "when SSO is disabled" do
      let(:oidc_config) { mock_oidc_config(enabled: false) }

      it "redirects to root" do
        get "/auth/sso/callback", params: { code: valid_code, state: "any-state" }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /auth/sso/logout" do
    context "when user is signed in" do
      let(:user) { create(:user, :as_caseworker, provider: "sso") }

      before { login_as(user) }

      it "signs out the user" do
        delete "/auth/sso/logout"

        expect(controller.current_user).to be_nil
      end

      it "redirects to root path" do
        delete "/auth/sso/logout"

        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not signed in" do
      it "redirects to root path" do
        delete "/auth/sso/logout"

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
