# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::SessionsController do
  render_views

  # Hard-code so we can reliably connect the session to a test user we create
  let (:uid) { "mock-uid" }
  let (:uid_generator) { -> { uid } }

  before do
    # rubocop:disable RSpec/InstanceVariable
    @request.env["devise.mapping"] = Devise.mappings[:user]
    # rubocop:enable RSpec/InstanceVariable

    allow(controller).to receive(:auth_service).and_return(
      AuthService.new(Auth::MockAdapter.new(uid_generator: uid_generator))
    )
  end

  describe "GET new" do
    it "renders the login form" do
      get :new, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /sign in/i)
    end
  end

  describe "POST create" do
    it "renders the form with errors if credentials are wrong" do
      post :create, params: {
        users_new_session_form: {
          email: "text@example.com",
          password: "wrong"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
      expect(response.body).to have_selector("h1", text: /sign in/i)
      expect(response.body).to have_selector(".usa-alert--error")
    end

    it "signs in a user and redirects to their account page (for now)" do
      create(:user, uid: uid)

      post :create, params: {
        users_new_session_form: {
          email: "test@example.com",
          password: "password"
        },
        locale: "en"
      }

      expect(response).to redirect_to(dashboard_path)
    end

    it "signs in and redirects to MFA preference page if a preference is not set" do
      post :create, params: {
        users_new_session_form: {
          email: "test@example.com",
          password: "password"
        },
        locale: "en"
      }

      expect(response).to redirect_to(users_mfa_preference_path)
    end

    it "redirects to the verify account page if the user is not confirmed" do
      post :create, params: {
        users_new_session_form: {
          email: "unconfirmed@example.com",
          password: "password"
        },
        locale: "en"
      }

      expect(response).to redirect_to(users_verify_account_path)
    end

    it "redirects to the challenge page if MFA is required" do
      create(:user, uid: uid, mfa_preference: nil)

      post :create, params: {
        users_new_session_form: {
          email: "mfa@example.com",
          password: "password"
        },
        locale: "en"
      }

      expect(session[:challenge_session]).to eq("mock-session")
      expect(session[:challenge_email]).to eq("mfa@example.com")
      expect(response).to redirect_to(session_challenge_path)
    end

    it "handles submission by bots" do
      create(:user, uid: uid)

      post :create, params: {
        users_new_session_form: {
          email: "test@example.com",
          password: "password",
          spam_trap: "I am a bot"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end

  describe "GET challenge" do
    it "renders the MFA challenge form" do
      session[:challenge_session] = "session"
      session[:challenge_email] = "test@example.com"

      get :challenge, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /enter your authentication app code/i)
    end

    it "redirects to the login page if there is no challenge session" do
      get :challenge, params: { locale: "en" }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST respond_to_challenge" do
    it "renders the form with errors if the code is invalid" do
      session[:challenge_session] = "session"
      session[:challenge_email] = "test@example.com"

      post :respond_to_challenge, params: {
        users_auth_app_code_form: {
          code: "wrong"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
      expect(response.body).to have_selector(".usa-alert--error")
    end

    it "signs in a user and redirects to their account page (for now)" do
      create(:user, uid: uid)
      session[:challenge_session] = "session"
      session[:challenge_email] = "test@example.com"

      post :respond_to_challenge, params: {
        users_auth_app_code_form: {
          code: "123456"
        },
        locale: "en"
      }

      expect(response).to redirect_to(dashboard_path)
    end
  end
end
