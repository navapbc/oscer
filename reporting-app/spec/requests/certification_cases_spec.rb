# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/certification_cases", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_caseworker, region: "north") }
  let(:certification) { create(:certification, certification_requirements: build(:certification_certification_requirements, region: "north")) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
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

  describe "GET /index" do
    before do
      create(
        :certification_case,
        :actionable,
        certification: create(:certification, case_number: "actionable_case", certification_requirements: build(:certification_certification_requirements, region: "north"))
      )
      create(
        :certification_case,
        :with_closed_status,
        certification: create(:certification, case_number: "closed_case", certification_requirements: build(:certification_certification_requirements, region: "north"))
      )
      create(
        :certification_case, :waiting_on_member,
        certification: create(:certification, case_number: "waiting", certification_requirements: build(:certification_certification_requirements, region: "north"))
      )
    end

    it "returns http success" do
      get "/staff/certification_cases"
      expect(response).to have_http_status(:success)
    end

    it "lists only open certification cases" do
      get "/staff/certification_cases"
      expect(response.body).to include("actionable_case")
      expect(response.body).to include("waiting")
      expect(response.body).not_to include("closed_case")
    end
  end
end
