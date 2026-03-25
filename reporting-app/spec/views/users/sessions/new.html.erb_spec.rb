# frozen_string_literal: true

require "rails_helper"

RSpec.describe "users/sessions/new", type: :view do
  let(:form) { Users::NewSessionForm.new }

  before do
    assign(:form, form)
    # Stub route helpers
    allow(view).to receive_messages(
      new_user_session_path: "/users/sign_in",
      users_forgot_password_path: "/users/forgot-password",
      users_new_registration_path: "/users/registrations"
    )
  end

  context "when member OIDC is enabled" do
    before do
      allow(view).to receive_messages(
        member_oidc_enabled?: true,
        member_oidc_login_path: "/member_oidc/login"
      )
    end

    it "displays the member OIDC login button" do
      render

      expect(rendered).to have_link(
        I18n.t("auth.member_oidc.sign_in_button"),
        href: "/member_oidc/login"
      )
    end

    it "displays the member OIDC description" do
      render

      expect(rendered).to have_content(I18n.t("auth.member_oidc.sign_in_description"))
    end

    it "displays the divider" do
      render

      expect(rendered).to have_content(I18n.t("users.sessions.new.or_divider"))
    end

    it "still displays the regular login form" do
      render

      expect(rendered).to have_css("input[type='email']")
      expect(rendered).to have_css("input[type='password']")
    end
  end

  context "when member OIDC is disabled" do
    before do
      allow(view).to receive(:member_oidc_enabled?).and_return(false)
    end

    it "does not display the member OIDC login button" do
      render

      expect(rendered).not_to have_link(I18n.t("auth.member_oidc.sign_in_button"))
    end

    it "does not display the member OIDC description" do
      render

      expect(rendered).not_to have_content(I18n.t("auth.member_oidc.sign_in_description"))
    end

    it "does not display the divider" do
      render

      expect(rendered).not_to have_css(".border-top.border-base-lighter.margin-y-4")
    end

    it "displays the regular login form" do
      render

      expect(rendered).to have_css("input[type='email']")
      expect(rendered).to have_css("input[type='password']")
    end
  end
end
