# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ExemptionScreeners", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, email: "test@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:certification) { create(:certification, :connected_to_email, email: user.email) }
  let(:certification_case) { create(:certification_case, certification: certification) }

  before do
    login_as user
  end

  describe "GET /index" do
    it "returns http success when given certification case" do
      get exemption_screener_path(certification_case_id: certification_case.id)
      expect(response).to have_http_status(:success)
    end

    it "returns http redirect if not given certification case" do
      get exemption_screener_path
      expect(response).to have_http_status(:redirect)
    end
  end
end
