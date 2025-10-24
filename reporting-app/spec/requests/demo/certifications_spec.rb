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
      certification_date: "09/25/2025"
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
    end
  end
end
