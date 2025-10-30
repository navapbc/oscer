# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::PasswordsController do
  render_views

  before do
    allow(controller).to receive(:auth_service).and_return(
      AuthService.new(Auth::MockAdapter.new)
    )
  end

  describe "GET forgot" do
    it "renders the forgot password form" do
      get :forgot, params: { locale: "en" }

      expect(response.body).to have_field("users_forgot_password_form[email]")
    end
  end

  describe "POST send_reset_password_instructions" do
    it "redirects to the reset password form" do
      post :send_reset_password_instructions, params: {
        users_forgot_password_form: { email: "test@example.com" },
        locale: "en"
      }

      expect(response).to redirect_to(users_reset_password_path)
    end

    it "validates email" do
      post :send_reset_password_instructions, params: {
        users_forgot_password_form: { email: "invalid" },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles auth provider errors" do
      post :send_reset_password_instructions, params: {
        users_forgot_password_form: { email: "UsernameExists@example.com" },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles submission by bots" do
      post :send_reset_password_instructions, params: {
        users_forgot_password_form: { email: "UsernameExists@example.com", spam_trap: "I am a bot" },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end

  describe "GET reset" do
    it "renders the reset password form" do
      get :reset, params: { locale: "en" }

      expect(response.body).to have_field("users_reset_password_form[email]")
      expect(response.body).to have_field("users_reset_password_form[code]")
      expect(response.body).to have_field("users_reset_password_form[password]")
    end
  end

  describe "POST confirm_reset" do
    it "redirects to the login page" do
      post :confirm_reset, params: {
        users_reset_password_form: {
          email: "test@example.com",
          code: "123456",
          password: "password"
        },
        locale: "en"
      }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "validates email and code" do
      post :confirm_reset, params: {
        users_reset_password_form: {
          email: "invalid",
          code: "123456",
          password: "password"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles auth provider errors" do
      post :confirm_reset, params: {
        users_reset_password_form: {
          email: "test@example.com",
          code: "000001",
          password: "password"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end

    it "handles submission by bots" do
      post :confirm_reset, params: {
        users_reset_password_form: {
          email: "test@example.com",
          code: "123456",
          password: "password",
          spam_trap: "I am a bot"
        },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end
end
