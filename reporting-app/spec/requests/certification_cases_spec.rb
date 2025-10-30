# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/certification_cases", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "staff@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:certification_case) { create(:certification_case) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
    let(:certification) { Certification.find(certification_case.certification_id) }

    it "returns http success" do
      get "/staff/certification_cases/#{certification_case.id}"
      expect(response).to have_http_status(:success)
    end

    it "displays the certification case information" do
      get "/staff/certification_cases/#{certification_case.id}"
      expect(response.body).to include(certification.case_number)
      expect(response.body).to include(certification_case.status)
    end

    context "when certification case does not exist" do
      it "renders a 404 not found" do
        get "/staff/certification_cases/#{SecureRandom.uuid}"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
