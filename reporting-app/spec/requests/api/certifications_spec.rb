# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/api/certifications", type: :request do
  include Warden::Test::Helpers

  let(:member_user) { User.create!(email: "member@example.com", uid: SecureRandom.uuid, provider: "login.gov") }

  let(:valid_json_request_attributes) {
    {
      member_id: "foobar",
      member_data: {
        account_email: member_user.email
      },
      certification_requirements: build(:certification_certification_requirement_params, :with_direct_params).attributes.compact
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

  after do
    Warden.test_reset!
  end

  describe "GET /{id}" do
    it "renders a successful response" do
      certification = create(:certification)
      get api_certification_url(certification)
      expect(response).to be_successful
      expect(response).to match_openapi_doc(OPENAPI_DOC)
    end

    # TODO
    # it "renders a successful response with invalid data" do
    #   certification = create(:certification, :invalid_json_data)
    #   get api_certification_url(certification)
    #   expect(response).to be_successful
    #   # it won't necessarily match all of the spec, as the spec expects valid
    #   # data, so be more lenient here
    #   # expect(response).to match_openapi_doc(OPENAPI_DOC)
    # end
  end

  describe "POST /" do
    context "with valid parameters" do
      it "creates a new Certification" do
        expect {
          post api_certifications_url,
               params: valid_json_request_attributes,
               headers: valid_headers,
               as: :json
        }.to change(Certification, :count).by(1)
      end

      it "renders a JSON response with the new certification" do
        post api_certifications_url,
             params: valid_json_request_attributes,
             headers: valid_headers,
             as: :json
        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with no member info" do
      it "creates a new Certification" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.deep_merge({ member_id: "no_user" }),
              headers: valid_headers,
              as: :json
        }.to change(Certification, :count).by(1)
      end
    end

    context "with no matching member info" do
      it "creates a new Certification" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.deep_merge({ member_id: "no_user", member_data: { account_email: "neverfound@foo.com" } }),
              headers: valid_headers,
              as: :json
        }.to change(Certification, :count).by(1)
      end
    end

    context "with certification type" do
      it "creates a new Certification" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.merge({ certification_requirements: build(:certification_certification_requirement_params, :with_certification_type).attributes.compact }),
              headers: valid_headers
        }.to change(Certification, :count).by(1)
      end
    end

    context "with direct certification requirements" do
      it "creates a new Certification" do
        expect {
          post api_certifications_url,
              params: valid_json_request_attributes.merge({ certification_requirements: build(:certification_certification_requirements).attributes.compact }),
              headers: valid_headers
        }.to change(Certification, :count).by(1)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Certification" do
        expect {
          post api_certifications_url,
               params: invalid_request_attributes,
               as: :json
        }.not_to change(Certification, :count)
      end

      it "renders a JSON response with errors for the new certification" do
        post api_certifications_url,
             params: invalid_request_attributes,
             headers: valid_headers,
             as: :json
        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid cert requirements" do
        post api_certifications_url,
             params: valid_json_request_attributes.merge({ certification_requirements: { "lookback_period": 2 } }),
             headers: valid_headers,
             as: :json
        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end
  end
end
