# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController do
  render_views

  before do
    allow(controller).to receive(:auth_service).and_return(
      AuthService.new(Auth::MockAdapter.new)
    )
  end

  describe "GET new" do
    it "renders" do
      get :new, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /create an account/i)
    end
  end

  describe "POST create" do
    it "creates a new user and routes to verify page" do
      email = "test@example.com"

      post :create, params: {
        users_registration_form: {
          email: email,
          password: "password"
        },
        locale: "en"
      }
      user = User.find_by(email: email)

      expect(user).to be_present
      expect(response).to redirect_to(users_verify_account_path)
    end

    it "validates email" do
      post :create, params: {
        users_registration_form: {
          email: "invalid",
          password: "password"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles auth provider errors" do
      post :create, params: {
        users_registration_form: {
          email: "UsernameExists@example.com",
          password: "password"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles submission by bots" do
      email = "test@example.com"

      post :create, params: {
        users_registration_form: {
          email: email,
          password: "password",

          spam_trap: "I am a bot"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end

  describe "GET new_account_verification" do
    it "renders the account verification form" do
      get :new_account_verification, params: { locale: "en" }

      expect(response.body).to have_field("users_verify_account_form[code]")
    end
  end

  describe "POST create_account_verification" do
    it "redirects to sign in" do
      post :create_account_verification, params: {
        users_verify_account_form: {
          email: "test@example.com",
          code: "123456"
        },
        locale: "en"
      }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "validates email" do
      post :create_account_verification, params: {
        users_verify_account_form: {
          email: "invalid",
          code: "123456"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles auth provider errors" do
      post :create_account_verification, params: {
        users_verify_account_form: {
          email: "test@example.com",
          code: "000001"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end
end
