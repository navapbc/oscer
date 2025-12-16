# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/certification_cases", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_caseworker, region: "north") }
  let(:certification) { create(:certification, certification_requirements: build(:certification_certification_requirements, region: "north")) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    login_as user
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
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

    context "with hours reported" do
      let(:member_id) { certification.member_id }
      let(:lookback_period) { certification.certification_requirements.continuous_lookback_period }

      before do
        # Create activities within the certification's lookback period
        period_start = lookback_period.start
        period_end = lookback_period.start.end_of_month

        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 20,
               period_start: period_start,
               period_end: period_end)
        create(:ex_parte_activity,
               member_id: member_id,
               category: "community_service",
               hours: 15,
               period_start: period_start,
               period_end: period_end)
      end

      it "displays the hours reported table" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("Ex Parte Data")
        expect(response.body).to include("Organization name")
        expect(response.body).to include("Source")
        expect(response.body).to include("Activity type")
      end

      it "displays ex parte activities" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("From the State")
        expect(response.body).to include("Employment")
        expect(response.body).to include("Community Service")
      end

      it "displays total and required hours" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("Total reported")
        expect(response.body).to include("Required")
        expect(response.body).to include("Additional hours needed")
      end
    end

    context "without hours reported" do
      it "displays no hours message" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("No hours reported")
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
