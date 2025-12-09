# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/users", type: :request do
  include Warden::Test::Helpers

  let(:staff_user) { create(:user) }

  before do
    login_as staff_user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /index" do
    it "renders a successful response with users" do
      create_list(:user, 3, role: "caseworker")
      get "/staff/users"
      expect(response).to be_successful
      expect(response.body).to include("Manage Team Members")
    end
  end
end
