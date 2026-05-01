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

        create(:external_hourly_activity,
               member_id: member_id,
               category: "employment",
               hours: 20,
               period_start: period_start,
               period_end: period_end)
        create(:external_hourly_activity,
               member_id: member_id,
               category: "community_service",
               hours: 15,
               period_start: period_start,
               period_end: period_end)
        create(:external_hourly_activity,
               member_id: member_id,
               category: "community_service",
               hours: 15,
               period_start: period_start,
               period_end: period_end)
        form = create(
          :activity_report_application_form,
          certification_case_id: certification_case.id,
        )
        form.activities.create(
          hours: 10,
          name: "Employer Inc",
          type: "WorkActivity",
          month: period_start
        )
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
        expect(response.body).to include("Self-reported")
        expect(response.body).to include("Employer Inc")
      end

      it "displays total and required hours" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("Total reported")
        expect(response.body).to include("60")
        expect(response.body).to include("Required")
        expect(response.body).to include("80")
        expect(response.body).to include("Additional hours needed")
        expect(response.body).to include("20")
      end
    end

    context "without hours reported" do
      it "displays no hours message" do
        get "/staff/certification_cases/#{certification_case.id}"
        expect(response.body).to include("No hours reported")
      end
    end

    context "with doc_ai feature flag" do
      let(:ai_user) { create(:user) }
      let(:form) do
        create(:activity_report_application_form, certification_case_id: certification_case.id)
      end
      let(:activity) do
        form.activities.create!(
          name: "Test Employer",
          type: "WorkActivity",
          hours: 40,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
      end

      before do
        activity
      end

      context "when doc_ai is enabled" do
        it "shows confidence column header" do
          with_doc_ai_enabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).to include("Confidence Level")
          end
        end

        it "shows evidence source icon" do
          with_doc_ai_enabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).to include("#insights")
          end
        end


        it "renders confidence percentage for ai_sourced activity" do
          create(:staged_document, :validated,
            stageable: activity,
            user_id: ai_user.id,
            extracted_fields: { "grosspay" => { "confidence" => 0.93, "value" => 1000 } })

          with_doc_ai_enabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).to include("93%")
          end
        end

        it "shows blank confidence for self_reported activity" do
          form.activities.create!(
            name: "Manual Co",
            type: "WorkActivity",
            hours: 20,
            month: Date.current.beginning_of_month,
            category: "employment",
            evidence_source: "self_reported"
          )

          with_doc_ai_enabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).to include("#person")
            # Self-reported activities show "—" (em dash) instead of a percentage
            expect(response.body).to include("—")
          end
        end
      end

      context "when doc_ai is disabled" do
        it "does not show confidence column" do
          with_doc_ai_disabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).not_to include("Confidence Level")
          end
        end

        it "does not show evidence source icons" do
          with_doc_ai_disabled do
            get "/staff/certification_cases/#{certification_case.id}"
            expect(response.body).not_to include("#insights")
          end
        end
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

  describe "GET /closed" do
    before do
      create(
        :certification_case,
        :with_closed_status,
        certification: create(
          :certification,
          case_number: "closed_case_1",
          certification_requirements: build(:certification_certification_requirements, region: "north")
        )
      )
      create(
        :certification_case,
        :with_closed_status,
        certification: create(
          :certification,
          case_number: "closed_case_2",
          certification_requirements: build(:certification_certification_requirements, region: "north")
        )
      )
      create(
        :certification_case,
        :actionable,
        certification: create(
          :certification,
          case_number: "open_case",
          certification_requirements: build(:certification_certification_requirements, region: "north")
        )
      )
    end

    it "returns http success" do
      get "/staff/certification_cases/closed"
      expect(response).to have_http_status(:ok)
    end

    it "lists only closed certification cases" do
      get "/staff/certification_cases/closed"
      expect(response.body).to include("closed_case_1")
      expect(response.body).to include("closed_case_2")
      expect(response.body).not_to include("open_case")
    end
  end
end
