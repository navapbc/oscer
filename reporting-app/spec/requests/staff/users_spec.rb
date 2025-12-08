# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/users", type: :request do
  include Warden::Test::Helpers

  after do
    Warden.test_reset!
  end

  describe "GET /index" do
    context "when the user is a member" do
      before do
        login_as create(:user)
      end

      it "renders a 403 response" do
        get "/staff/users"
        expect(response).to redirect_to("/staff")
      end
    end

    context "when the user is a caseworker" do
      before do
        login_as create(:user, :as_caseworker)
      end

      it "renders a successful response" do
        get "/staff/users"
        expect(response).to redirect_to("/staff")
      end
    end

    context "when the user is an admin" do
      before do
        login_as create(:user, :as_admin)
      end

      it "renders a successful response" do
        get "/staff/users"
        expect(response).to be_successful
      end
    end
  end
end
