# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/demo/certifications", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, email: "foo@example.com") }

  let(:valid_request_attributes) {
    {
      member_email: "foo@example.com",
      member_name_first: "Jane",
      member_name_last: "Doe",
      case_number: "C-123",
      certification_date: "09/25/2025",
      date_of_birth: "01/15/1990"
    }
  }

  after do
    Warden.test_reset!
  end

  # In development/test the gate always allows access (matching today's DX), so
  # the examples below exercise the un-gated behavior. The "feature gating"
  # context simulates a deployed (non-local) environment where the flag governs.

  describe "feature gating in a deployed environment" do
    before do
      allow(Rails.env).to receive(:local?).and_return(false)
    end

    context "when FEATURE_DEMO_CERTIFICATIONS is disabled" do
      it "returns 404 for GET /new" do
        with_demo_certifications_disabled do
          get new_demo_certification_url
        end
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 and creates nothing for POST /create" do
        with_demo_certifications_disabled do
          expect {
            post demo_certifications_url,
                 params: { demo_certifications_create_form: valid_request_attributes }
          }.not_to change(Certification, :count)
        end
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when FEATURE_DEMO_CERTIFICATIONS is enabled" do
      it "allows GET /new" do
        with_demo_certifications_enabled do
          get new_demo_certification_url
        end
        expect(response).to be_successful
      end

      it "allows POST /create to seed a Certification" do
        with_demo_certifications_enabled do
          expect {
            post demo_certifications_url,
                 params: { demo_certifications_create_form: valid_request_attributes }
          }.to change(Certification, :count).by(1)

          cert = Certification.order(created_at: :desc).first
          expect(response).to redirect_to(certification_path(cert))
        end
      end
    end
  end

  describe "GET /new" do
    it "renders Generic form by default" do
      get new_demo_certification_url
      expect(response).to be_successful
    end

    it "renders New Application form" do
      get new_demo_certification_url, params: { certification_type: "new_application" }
      expect(response).to be_successful
    end

    it "renders Recertification form" do
      get new_demo_certification_url, params: { certification_type: "recertification" }
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    it "creates a new Certification" do
      create_attrs = build(:certification_certification_requirement_params, :with_direct_params).attributes.compact.deep_merge(valid_request_attributes)

      expect {
        post demo_certifications_url,
             params: {
               demo_certifications_create_form: create_attrs
             }
      }.to change(Certification, :count).by(1)

      cert = Certification.order(created_at: :desc).last
      expect(cert.case_number).to eq(create_attrs[:case_number])
      expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
      expect(cert.certification_requirements.due_date).not_to be_nil
      expect(cert.member_name).to eq(Strata::Name.new({
        "first": create_attrs[:member_name_first],
        "last": create_attrs[:member_name_last]
      }))
    end

    it "creates a new Certification with empty string certification_type" do
      expect {
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.deep_merge(
                   build(:certification_certification_requirement_params, :with_direct_params, certification_type: "").attributes.compact
                 )
             }
      }.to change(Certification, :count).by(1)
    end

    it "creates a new 'new_application' Certification" do
      create_attrs = valid_request_attributes.merge({ certification_type: "new_application" })

      expect {
        post demo_certifications_url,
             params: { demo_certifications_create_form: create_attrs }
      }.to change(Certification, :count).by(1)

      cert = Certification.order(created_at: :desc).last
      expect(cert.case_number).to eq(create_attrs[:case_number])
      expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
      expect(cert.certification_requirements.due_date).not_to be_nil
      expect(cert.certification_requirements.certification_type).to eq("new_application")
      expect(cert.member_name).to eq(Strata::Name.new({
        "first": create_attrs[:member_name_first],
        "last": create_attrs[:member_name_last]
      }))
    end

    it "creates a new 'recertification' Certification" do
      expect {
        post demo_certifications_url,
             params: { demo_certifications_create_form: valid_request_attributes.merge({ certification_type: "recertification" }) }
      }.to change(Certification, :count).by(1)
    end

    context "when using external scenarios" do
      it "creates Certification with 'Partially met work hours requirement'" do
        create_attrs = valid_request_attributes.merge({ external_scenario: "Partially met work hours requirement" })

        expect {
          post demo_certifications_url,
              params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)
          .and change(ExternalHourlyActivity, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.activities).not_to be_nil
        expect(cert.member_data.activities.length).to eq(1)
        expect(cert.member_data.activities.first.hours).to eq(10)

        activity = ExternalHourlyActivity.last
        expect(activity.member_id).to eq(cert.member_id)
        expect(activity.category).to eq("employment")
        expect(activity.hours).to eq(10)
        expect(activity.period_start).to eq(cert.certification_requirements.certification_date.beginning_of_month)
        expect(activity.period_end).to eq(cert.certification_requirements.certification_date.end_of_month)
        expect(activity.source_type).to eq("api")
        expect(activity.source_id).to be_nil
      end

      it "creates Certification with 'Fully met work hours requirement'" do
        create_attrs = valid_request_attributes.merge({ external_scenario: "Fully met work hours requirement" })

        expect {
          post demo_certifications_url,
              params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)
          .and change(ExternalHourlyActivity, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.activities).not_to be_nil
        expect(cert.member_data.activities.sum(&:hours)).to eq(80)

        activity = ExternalHourlyActivity.last
        expect(activity.member_id).to eq(cert.member_id)
        expect(activity.category).to eq("employment")
        expect(activity.hours).to eq(80)
        expect(activity.source_type).to eq("api")
        expect(activity.source_id).to be_nil
      end

      it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses scenario DOB" do
        create_attrs = valid_request_attributes.except(:date_of_birth).merge({ external_scenario: "Meets age-based exemption requirement" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.date_of_birth).to be_between(
          cert.certification_requirements.certification_date - 18.years, cert.certification_requirements.certification_date - 1.years
        )
      end

      it "creates Certification with 'Partially met income requirement'" do
        create_attrs = valid_request_attributes.merge({ external_scenario: "Partially met income requirement" })

        expect {
          post demo_certifications_url,
              params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)
          .and change(ExternalIncomeActivity, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.activities).not_to be_nil
        expect(cert.member_data.activities.sum(&:gross_income)).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY / 2.0)

        activity = ExternalIncomeActivity.last
        expect(activity.member_id).to eq(cert.member_id)
        expect(activity.category).to eq("employment")
        expect(activity.gross_income).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY / 2.0)
        expect(activity.source_type).to eq("api")
        expect(activity.period_start).to eq(cert.certification_requirements.certification_date.beginning_of_month)
        expect(activity.period_end).to eq(cert.certification_requirements.certification_date.end_of_month)
        expect(activity.source_id).to be_nil
      end

      it "creates Certification with 'Fully met income requirement'" do
        create_attrs = valid_request_attributes.merge({ external_scenario: "Fully met income requirement" })

        expect {
          post demo_certifications_url,
              params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)
          .and change(ExternalIncomeActivity, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.activities).not_to be_nil
        expect(cert.member_data.activities.sum(&:gross_income)).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY)

        activity = ExternalIncomeActivity.last
        expect(activity.member_id).to eq(cert.member_id)
        expect(activity.category).to eq("employment")
        expect(activity.gross_income).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY)
        expect(activity.source_type).to eq("api")
        expect(activity.period_start).to eq(cert.certification_requirements.certification_date.beginning_of_month)
        expect(activity.period_end).to eq(cert.certification_requirements.certification_date.end_of_month)
        expect(activity.source_id).to be_nil
      end

      it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses form DOB over scenario DOB" do
        create_attrs = valid_request_attributes.merge({ external_scenario: "Meets age-based exemption requirement" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)
        cert = Certification.order(created_at: :desc).last
        expect(cert.case_number).to eq(create_attrs[:case_number])
        expect(cert.certification_requirements.certification_date).to eq(Date.new(2025, 9, 25))
        expect(cert.certification_requirements.due_date).not_to be_nil
        expect(cert.member_name).to eq(Strata::Name.new({
          "first": create_attrs[:member_name_first],
          "last": create_attrs[:member_name_last]
        }))
        expect(cert.member_data.date_of_birth).to eq(Date.new(1990, 1, 15))
      end

      it "writes the certification date to pregnancy_due_or_parturition_date when the pregnancy_status checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ pregnancy_status: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.pregnancy_due_or_parturition_date).to eq(cert.certification_requirements.certification_date)
      end

      it "sets was_in_foster_care when the was_in_foster_care checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ was_in_foster_care: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.was_in_foster_care).to be true
      end

      it "sets currently_medically_frail when the currently_medically_frail checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ currently_medically_frail: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.currently_medically_frail).to be true
      end

      it "sets veteran_with_disability when the veteran_with_disability checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ veteran_with_disability: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.veteran_with_disability).to be true
      end

      it "sets dates_caretaking_infirm to the certification date when the caretaker checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ caretaker: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.dates_caretaking_infirm).to eq([ cert.certification_requirements.certification_date ])
      end

      it "sets meeting_tanf_or_snap_work when the checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ tanf_snap_work: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.meeting_tanf_or_snap_work).to be true
      end

      it "sets dates_in_drug_treatment to the certification date when the checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ drug_treatment: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.dates_in_drug_treatment).to eq([ cert.certification_requirements.certification_date ])
      end

      it "sets dates_incarcerated to the certification date when the checkbox is selected" do
        create_attrs = valid_request_attributes.merge({ inmate: "1", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.dates_incarcerated).to eq([ cert.certification_requirements.certification_date ])
      end

      it "creates a new Certification with an external exception selected" do
        create_attrs = valid_request_attributes.merge({ external_exception: "inpatient_medical_care", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.dates_receiving_inpatient_medical_care).to eq cert.certification_requirements.months_that_can_be_certified
      end

      it "creates a new Certification with race_ethnicity selected" do
        create_attrs = valid_request_attributes.merge({ race_ethnicity: "white", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.race_ethnicity).to eq("white")
      end

      it "creates a new Certification with icn entered" do
        create_attrs = valid_request_attributes.merge({ va_icn: "1012861229V078999", external_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.va_icn).to eq("1012861229V078999")
      end
    end

    context "with region" do
      before do
        create(:user, region: "northeast")
      end

      it "creates a certification with a valid region" do
        create_attrs = valid_request_attributes.merge({ region: "northeast" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.certification_requirements.region).to eq("northeast")
      end

      it "creates a certification without a region" do
        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: valid_request_attributes }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.certification_requirements.region).to be_nil
      end

      it "renders form with errors when region is invalid" do
        create_attrs = valid_request_attributes.merge({ region: "invalid_region" })

        post demo_certifications_url,
             params: { demo_certifications_create_form: create_attrs }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with validation errors" do
      it "renders form with errors when certification_date is missing" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:certification_date).merge(
                   member_name_first: "Jane",
                   member_name_last: "Doe"
                 )
             }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders form with errors when member_name_first is missing" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:member_name_first).merge(
                   certification_date: "09/25/2025"
                 )
             }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders form with errors when member_name_last is missing" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:member_name_last).merge(
                   certification_date: "09/25/2025"
                 )
             }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders form with errors when date_of_birth is in the future" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.merge(
                   date_of_birth: (Date.current + 1.day).strftime("%m/%d/%Y")
                 )
             }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
