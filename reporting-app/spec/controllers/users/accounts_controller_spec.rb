# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::AccountsController do
  render_views

  before do
    allow(controller).to receive(:auth_service).and_return(
      AuthService.new(Auth::MockAdapter.new)
    )
  end

  describe "GET edit" do
    it "renders the account edit form" do
      user = create(:user)
      sign_in user

      get :edit, params: { locale: "en" }

      expect(response.body).to have_field("users_update_email_form[email]", with: user.email)
    end

    it "shows disable MFA button if MFA is enabled" do
      user = create(:user, mfa_preference: "software_token")
      sign_in user

      get :edit, params: { locale: "en" }

      expect(response.body).to have_element("button", text: /disable multi-factor/i)
    end

    it "shows enable MFA button if MFA is disabled" do
      user = create(:user, mfa_preference: "opt_out")
      sign_in user

      get :edit, params: { locale: "en" }

      expect(response.body).to have_element("a", text: /enable multi-factor/i)
    end
  end

  describe "PATCH update_email" do
    it "updates the user's email" do
      new_email = "new@example.com"
      user = create(:user)
      sign_in user

      patch :update_email, params: {
        users_update_email_form: { email: new_email },
        locale: "en"
      }
      user.reload

      expect(user.email).to eq(new_email)
    end

    it "validates the email" do
      user = create(:user)
      sign_in user

      patch :update_email, params: {
        users_update_email_form: { email: "invalid-email" },
        locale: "en"
      }

      expect(response.status).to eq(422)
    end
  end
end
