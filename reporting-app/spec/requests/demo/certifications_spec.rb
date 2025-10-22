# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/demo/certifications", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "foo@example.com", uid: SecureRandom.uuid, provider: "login.gov") }

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
      expect {
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.deep_merge(
                   build(:certification_certification_requirement_params, :with_direct_params).attributes.compact
                 )
             }
      }.to change(Certification, :count).by(1)
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
      expect {
        post demo_certifications_url,
             params: { demo_certifications_create_form: valid_request_attributes.merge({ certification_type: "new_application" }) }
      }.to change(Certification, :count).by(1)
    end

    it "creates a new 'recertification' Certification" do
      expect {
        post demo_certifications_url,
             params: { demo_certifications_create_form: valid_request_attributes.merge({ certification_type: "recertification" }) }
      }.to change(Certification, :count).by(1)
    end

    it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses scenario DOB" do
      expect {
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:date_of_birth).deep_merge(
                   build(:certification_certification_requirement_params, :with_direct_params).attributes.compact
                 ).merge(
                   ex_parte_scenario: "Meets age-based exemption requirement"
                 )
             }
      }.to change(Certification, :count).by(1)

      certification = Certification.last
      expect(certification.member_data["date_of_birth"]).to be_present
    end

    it "creates a new Certification with 'Meets age-based exemption requirement' scenario and uses form DOB over scenario DOB" do
      expect {
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.merge(date_of_birth: "01/15/1900").merge(ex_parte_scenario: "Meets age-based exemption requirement")
             }
      }.to change(Certification, :count).by(1)
      certification = Certification.last
      expect(certification.member_data["date_of_birth"]).to eq("1900-01-15")
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
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders form with errors when member_name_first is missing" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:member_name_first).merge(
                   certification_date: "09/25/2025"
                 )
             }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders form with errors when member_name_last is missing" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.except(:member_name_last).merge(
                   certification_date: "09/25/2025"
                 )
             }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders form with errors when date_of_birth is in the future" do
        post demo_certifications_url,
             params: {
               demo_certifications_create_form:
                 valid_request_attributes.merge(
                   date_of_birth: (Date.current + 1.day).strftime("%m/%d/%Y")
                 )
             }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
