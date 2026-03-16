# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::MemberOidcController do
  render_views

  include SsoHelpers
  include Warden::Test::Helpers

  let(:member_oidc_config) { mock_member_oidc_config }

  before do
    # rubocop:disable RSpec/InstanceVariable
    @request.env["devise.mapping"] = Devise.mappings[:user]
    # rubocop:enable RSpec/InstanceVariable
    configure_member_oidc_for_test(member_oidc_config)
  end

  after do
    Warden.test_reset!
  end

  describe "GET new" do
    context "when member OIDC is enabled" do
      it "renders the auto-submit form page" do
        get :new, params: { locale: "en" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="/auth/member_oidc"')
        expect(response.body).to include('method="post"')
      end
    end

    context "when member OIDC is disabled" do
      let(:member_oidc_config) { mock_member_oidc_config(enabled: false) }

      it "redirects to member sign-in with not_enabled message" do
        get :new, params: { locale: "en" }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("not available")
      end
    end

    context "when user is already authenticated" do
      let(:user) { create(:user, provider: "member_oidc") }

      before { sign_in(user) }

      it "redirects to after_sign_in_path" do
        get :new, params: { locale: "en" }

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include("/auth/member_oidc")
      end
    end

    context "with origin parameter" do
      it "includes origin in the form as a hidden field" do
        get :new, params: { origin: "/dashboard", locale: "en" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="origin"')
        expect(response.body).to include("/dashboard")
      end
    end
  end

  describe "GET callback" do
    before do
      request.env["omniauth.auth"] = auth_hash
    end

    let(:auth_hash) { mock_member_omniauth_hash }

    context "with successful authentication" do
      it "creates a new user session" do
        get :callback, params: { locale: "en" }

        expect(response).to have_http_status(:redirect)
        expect(controller.current_user).to be_present
      end

      it "provisions a new user from claims" do
        expect {
          get :callback, params: { locale: "en" }
        }.to change(User, :count).by(1)
      end

      it "sets provider to member_oidc" do
        get :callback, params: { locale: "en" }

        expect(controller.current_user.provider).to eq("member_oidc")
      end

      it "finds existing user by UID on subsequent login" do
        get :callback, params: { locale: "en" }
        created_user = User.last
        logout

        request.env["omniauth.auth"] = auth_hash
        expect {
          get :callback, params: { locale: "en" }
        }.not_to change(User, :count)

        expect(controller.current_user).to eq(created_user)
      end

      it "does not raise for no role (member has no staff role)" do
        expect { get :callback, params: { locale: "en" } }.not_to raise_error
      end
    end

    context "when omniauth.auth is missing" do
      let(:auth_hash) { nil }

      it "redirects to member sign-in with alert" do
        get :callback, params: { locale: "en" }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("Authentication failed")
      end
    end

    context "when claims are invalid (missing email)" do
      let(:auth_hash) do
        mock_member_omniauth_hash(
          extra: { raw_info: { "sub" => "member-123", "email" => nil, "name" => "Test" } }
        )
      end

      it "redirects to member sign-in with alert" do
        get :callback, params: { locale: "en" }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("Authentication failed")
      end
    end
  end

  describe "GET failure" do
    it "redirects to member sign-in with alert" do
      get :failure, params: { message: "invalid_credentials", locale: "en" }

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include("Authentication failed")
    end
  end
end
