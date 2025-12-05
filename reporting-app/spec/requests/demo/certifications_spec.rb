# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/demo/certifications", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, email: "foo@example.com", uid: SecureRandom.uuid, provider: "login.gov") }

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

    context "when using ex parte scenarios" do
      it "creates Certification with 'Partially met work hours requirement'" do
        create_attrs = valid_request_attributes.merge({ ex_parte_scenario: "Partially met work hours requirement" })

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
      end

      it "creates Certification with 'Fully met work hours requirement'" do
        create_attrs = valid_request_attributes.merge({ ex_parte_scenario: "Fully met work hours requirement" })

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
      end

      it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses scenario DOB" do
        create_attrs = valid_request_attributes.except(:date_of_birth).merge({ ex_parte_scenario: "Meets age-based exemption requirement" })

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

      it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses form DOB over scenario DOB" do
        create_attrs = valid_request_attributes.merge({ ex_parte_scenario: "Meets age-based exemption requirement" })

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

      it "creates a new Certification with pregnancy_status checkbox selected" do
        create_attrs = valid_request_attributes.merge({ pregnancy_status: "1", ex_parte_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.pregnancy_status).to be true
      end

      it "creates a new Certification with race_ethnicity selected" do
        create_attrs = valid_request_attributes.merge({ race_ethnicity: "white", ex_parte_scenario: "No data" })

        expect {
          post demo_certifications_url,
               params: { demo_certifications_create_form: create_attrs }
        }.to change(Certification, :count).by(1)

        cert = Certification.order(created_at: :desc).last
        expect(cert.member_data.race_ethnicity).to eq("white")
      end
    end

    context "with region" do
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
