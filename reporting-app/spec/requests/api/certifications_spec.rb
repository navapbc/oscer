# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/api/certifications", type: :request do
  include Warden::Test::Helpers

  let(:member_user) { create(:user) }

  let(:valid_json_request_attributes) {
    {
      member_id: "foobar",
      member_data: {
        account_email: member_user.email,
        name: {
          first: "John",
          last: "Doe"
        }
      },
      certification_requirements: build(:certification_certification_requirement_params, :with_direct_params).as_json
    }
  }

  let(:invalid_request_attributes) {
    {
      certification_requirements: "()"
    }
  }

  # This should return the minimal set of values that should be in the headers
  # in order to pass any filters (e.g. authentication) defined in
  # CertificationsController, or in your router and rack
  # middleware. Be sure to keep this updated too.
  let(:valid_headers) {
    {}
  }

  let(:valid_certifications) {
    [
      create(:certification),
      create(:certification,
             "member_data": build(:certification_member_data,
                                  :with_full_name,
                                  :with_account_email,
                                  :partially_met_work_hours_requirement
                                 )
            ),
      create(:certification,
             "certification_requirements": build(:certification_certification_requirements,
                                                 "certification_type": "new_application"
                                                )
            )
    ]
  }

  after do
    Warden.test_reset!
  end

  describe "GET /{id}" do
    it "renders a successful response" do
      valid_certifications.each do |certification|
        get api_certification_url(certification)
        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    it "renders a successful response with invalid data" do
      certification = create(:certification)
      certification.update_column("certification_requirements", "()")
      get api_certification_url(certification)
      expect(response).to be_successful
      expect(response).to match_openapi_doc(OPENAPI_DOC)
    end
  end

  describe "POST /" do
    context "with valid parameters" do
      it "creates a new Certification and renders response" do
        expect {
          post api_certifications_url,
               params: valid_json_request_attributes,
               headers: valid_headers,
               as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with no member info" do
      it "creates a new Certification and renders response" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.deep_merge({
                member_id: "no_user"
              }),
              headers: valid_headers,
              as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with no matching member info" do
      it "creates a new Certification and renders response" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.deep_merge({
                member_id: "no_user",
                member_data: { account_email: "neverfound@foo.com" }
              }),
              headers: valid_headers,
              as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with certification type" do
      it "creates a new Certification and renders response" do
        requirement_params = build(:certification_certification_requirement_params, :with_certification_type)

        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.merge({
                certification_requirements: requirement_params.as_json
              }),
              headers: valid_headers
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)

        requirement_params.validate
        cert = Certification.find(response.parsed_body[:id])
        expect(cert.certification_requirements).to eq(requirement_params.to_requirements)
      end
    end

    context "with direct certification requirements" do
      it "creates a new Certification and renders response" do
        certification_requirements = build(:certification_certification_requirements)

        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.merge({
                certification_requirements: certification_requirements.as_json
              }),
              headers: valid_headers
        }.to change(Certification, :count).by(1)

        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)

        cert = Certification.find(response.parsed_body[:id])
        expect(cert.certification_requirements).to eq(certification_requirements)
      end
    end

    context "with member data" do
      it "creates a new Certification and renders response" do
        member_data = build(:certification_member_data,
                            :with_full_name,
                            :with_account_email,
                            :partially_met_work_hours_requirement
                           )
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.merge({
                member_data: member_data.as_json
              }),
              headers: valid_headers
        }.to change(Certification, :count).by(1)

        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)

        cert = Certification.find(response.parsed_body[:id])
        expect(cert.member_data).to eq(member_data)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Certification and renders response" do
        expect {
          post api_certifications_url,
               params: invalid_request_attributes,
               as: :json
        }.not_to change(Certification, :count)

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid cert requirements - lookback_period" do
        post api_certifications_url,
             params: valid_json_request_attributes.merge({
               certification_requirements: { "lookback_period": 2 }
             }),
             headers: valid_headers,
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid cert requirements - array" do
        post api_certifications_url,
             params: valid_json_request_attributes.merge({
               certification_requirements: { "months_to_be_certified": [ "2025-10-16", "FOOBAR" ] }
             }),
             headers: valid_headers,
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end
  end
end
