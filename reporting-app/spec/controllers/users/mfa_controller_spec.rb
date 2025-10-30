# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::MfaController do
  render_views

  before do
    allow(controller).to receive(:auth_service).and_return(
      AuthService.new(Auth::MockAdapter.new)
    )
  end

  describe "preference" do
    it "renders the MFA preference form" do
      user = create(:user)
      sign_in user

      get :preference, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /multi-factor authentication/i)
    end
  end

  describe "update_preference" do
    it "updates the MFA preference for the user when opting out" do
      user = create(:user, mfa_preference: nil)
      sign_in user

      patch :update_preference, params: {
        users_mfa_preference_form: { mfa_preference: "opt_out" },
        locale: "en"
      }

      expect(user.mfa_preference).to be_nil
      user.reload
      expect(user.mfa_preference).to eq("opt_out")

      expect(response).to redirect_to(dashboard_path)
    end

    it "does not set preference when selecting software token" do
      user = create(:user, mfa_preference: nil)
      sign_in user

      patch :update_preference, params: {
        users_mfa_preference_form: { mfa_preference: "software_token" },
        locale: "en"
      }

      user.reload
      expect(user.mfa_preference).to be_nil
      expect(response).to redirect_to(action: :new)
    end
  end

  describe "new" do
    it "renders the MFA setup form" do
      user = create(:user, access_token: JWT.encode({ exp: 1.day.from_now.to_i }, nil))
      sign_in user

      get :new, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /add an authentication app/i)
      expect(response.body).to have_text("mock-secret")
    end

    it "redirects to the login page if the access token is close to expiring" do
      user = create(:user, access_token: JWT.encode({ exp: 5.minutes.from_now.to_i }, nil))
      sign_in user

      get :new, params: { locale: "en" }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "create" do
    it "associates the software token with the user" do
      user = create(
        :user,
        mfa_preference: nil,
        access_token: JWT.encode({ exp: 1.day.from_now.to_i }, nil)
      )
      sign_in user

      post :create, params: {
        users_associate_mfa_form: { temporary_code: "123123" },
        locale: "en"
      }

      expect(user.mfa_preference).not_to eq("software_token")
      user.reload
      expect(user.mfa_preference).to eq("software_token")

      expect(response).to redirect_to(root_path)
    end

    it "redirects back to the setup page if the code is invalid" do
      user = create(:user, access_token: JWT.encode({ exp: 1.day.from_now.to_i }, nil))
      sign_in user

      post :create, params: {
        users_associate_mfa_form: { temporary_code: "wrong format" },
        locale: "en"
      }

      expect(flash[:errors]).to include(/wrong length/i)
      expect(response).to redirect_to(action: :new)
    end

    it "redirects back to the setup page if the code is incorrect" do
      user = create(:user, access_token: JWT.encode({ exp: 1.day.from_now.to_i }, nil))
      sign_in user

      post :create, params: {
        users_associate_mfa_form: { temporary_code: "000001" },
        locale: "en"
      }

      expect(flash[:errors]).to include(/invalid code/i)
      expect(response).to redirect_to(action: :new)
    end
  end

  describe "destroy" do
    it "disables MFA for the user" do
      user = create(:user, mfa_preference: "software_token")
      sign_in user

      delete :destroy, params: { locale: "en" }

      user.reload
      expect(user.mfa_preference).to eq("opt_out")
    end
  end
end
