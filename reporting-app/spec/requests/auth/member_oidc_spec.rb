# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::MemberOidc", type: :request do
  include Warden::Test::Helpers

  let(:member_oidc_config) { mock_member_oidc_config }

  before do
    configure_member_oidc_for_test(member_oidc_config)
    setup_member_omniauth_mock
  end

  after do
    Warden.test_reset!
  end

  describe "GET /member_oidc/login (login initiation)" do
    context "when member OIDC is enabled" do
      it "renders the auto-submit form page" do
        get "/member_oidc/login"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="/auth/member_oidc"')
        expect(response.body).to include('method="post"')
      end
    end

    context "when member OIDC is disabled" do
      let(:member_oidc_config) { mock_member_oidc_config(enabled: false) }

      it "redirects to member sign-in with not_enabled message" do
        get "/member_oidc/login"

        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response.body).to include("not available")
      end
    end

    context "when user is already authenticated" do
      let(:user) { create(:user, provider: "member_oidc") }

      before { login_as(user) }

      it "redirects to after_sign_in_path" do
        get "/member_oidc/login"

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include("/auth/member_oidc")
      end
    end

    context "with origin parameter" do
      it "includes origin in the form as a hidden field" do
        get "/member_oidc/login", params: { origin: "/dashboard" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="origin"')
        expect(response.body).to include("/dashboard")
      end
    end
  end

  describe "GET /auth/member_oidc/callback" do
    context "with successful authentication" do
      it "creates a new user session" do
        get "/auth/member_oidc/callback"

        expect(response).to have_http_status(:redirect)
        expect(controller.current_user).to be_present
      end

      it "provisions a new user from claims" do
        expect {
          get "/auth/member_oidc/callback"
        }.to change(User, :count).by(1)
      end

      it "sets provider to member_oidc" do
        get "/auth/member_oidc/callback"

        expect(controller.current_user.provider).to eq("member_oidc")
      end

      it "finds existing user by UID on subsequent login" do
        get "/auth/member_oidc/callback"
        created_user = User.last
        logout

        expect {
          get "/auth/member_oidc/callback"
        }.not_to change(User, :count)

        expect(controller.current_user).to eq(created_user)
      end

      it "does not raise for no role (member has no staff role)" do
        expect { get "/auth/member_oidc/callback" }.not_to raise_error
      end
    end

    context "when claims are invalid (missing email)" do
      before do
        setup_member_omniauth_mock(mock_member_omniauth_hash(
          extra: { raw_info: { "sub" => "member-123", "email" => nil, "name" => "Test" } }
        ))
      end

      it "redirects to member sign-in with alert" do
        get "/auth/member_oidc/callback"

        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response.body).to include("Authentication failed")
      end
    end
  end

  describe "GET /auth/member_oidc/failure" do
    before do
      setup_member_omniauth_failure(:invalid_credentials)
    end

    it "redirects to member sign-in with alert" do
      get "/auth/member_oidc/failure", params: { message: "invalid_credentials" }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("Authentication failed")
    end
  end
end
