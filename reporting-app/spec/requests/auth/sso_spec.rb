# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Sso", type: :request do
  include Warden::Test::Helpers

  let(:sso_config) { mock_sso_config }

  before do
    configure_sso_for_test(sso_config)
    setup_omniauth_mock
  end

  after do
    Warden.test_reset!
  end

  describe "GET /sso/login (login initiation)" do
    context "when SSO is enabled" do
      it "redirects to OmniAuth request phase" do
        get "/sso/login"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/auth/sso")
      end
    end

    context "when SSO is disabled" do
      let(:sso_config) { mock_sso_config(enabled: false) }

      it "redirects to root with error message" do
        get "/sso/login"

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("SSO is not enabled")
      end
    end

    context "when user is already authenticated" do
      let(:user) { create(:user, :as_admin) }

      before { login_as(user) }

      it "redirects to dashboard" do
        get "/sso/login"

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include("/auth/sso")
      end
    end

    context "with origin parameter (deep link)" do
      it "passes origin to OmniAuth request phase" do
        get "/sso/login", params: { origin: "/certifications/123" }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/auth/sso")
        expect(response.location).to include("origin=")
      end
    end
  end

  describe "GET /auth/sso/callback" do
    context "with successful authentication" do
      it "creates a new user session" do
        get "/auth/sso/callback"

        expect(response).to have_http_status(:redirect)
        expect(controller.current_user).to be_present
      end

      it "provisions a new user from claims" do
        expect {
          get "/auth/sso/callback"
        }.to change(User, :count).by(1)
      end

      it "finds existing user by UID on subsequent login" do
        # First login creates user
        get "/auth/sso/callback"
        created_user = User.last
        logout

        # Second login should find existing user
        expect {
          get "/auth/sso/callback"
        }.not_to change(User, :count)

        expect(controller.current_user).to eq(created_user)
      end

      context "with deep link (omniauth.origin)" do
        before do
          # Pre-create user with MFA preference to skip MFA setup redirect
          create(:user, :as_caseworker,
            uid: "user-123",
            email: "staff@example.gov",
            provider: "sso",
            mfa_preference: "opt_out"
          )
          # Simulate OmniAuth storing the origin
          OmniAuth.config.before_callback_phase do |env|
            env["omniauth.origin"] = "/certifications/123"
          end
        end

        after do
          OmniAuth.config.before_callback_phase { |_env| }
        end

        it "redirects to the original requested path" do
          get "/auth/sso/callback"

          expect(response).to have_http_status(:redirect)
          expect(response.location).to include("/certifications/123")
        end
      end
    end

    context "when user's groups don't match any role" do
      before do
        setup_omniauth_mock(mock_omniauth_hash(
          extra: {
            raw_info: {
              "sub" => "user-123",
              "email" => "staff@example.gov",
              "name" => "Jane Doe",
              "groups" => [ "Unknown-Group" ]
            }
          }
        ))
      end

      it "redirects with access denied message" do
        get "/auth/sso/callback"

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("do not have permission")
      end

      it "does not create a user" do
        expect {
          get "/auth/sso/callback"
        }.not_to change(User, :count)
      end
    end
  end

  describe "GET /auth/failure" do
    before do
      setup_omniauth_failure(:invalid_credentials)
    end

    it "redirects with error message" do
      get "/auth/failure", params: { message: "invalid_credentials" }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Authentication failed")
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
