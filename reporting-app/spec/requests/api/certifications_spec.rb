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
    auth_headers(valid_json_request_attributes)
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

  def auth_headers(params = nil)
    body = params ? params.to_json : ""
    hmac_auth_headers(body: body, secret: Rails.configuration.api_secret_key)
  end

  after do
    Warden.test_reset!
  end

  describe "GET /{id}" do
    it "renders a successful response" do
      valid_certifications.each do |certification|
        get api_certification_url(certification), headers: auth_headers
        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    it "renders a successful response with invalid data" do
      certification = create(:certification)
      certification.update_column("certification_requirements", "()")
      get api_certification_url(certification), headers: auth_headers
      expect(response).to be_successful
      expect(response).to match_openapi_doc(OPENAPI_DOC)
    end
  end

  describe "POST /" do
    context "with valid parameters" do
      it "creates a new Certification and renders response" do
        params = valid_json_request_attributes
        expect {
          post api_certifications_url,
               params: params,
               headers: auth_headers(params),
               as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with no member info" do
      it "creates a new Certification and renders response" do
        params = valid_json_request_attributes.deep_merge({
          member_id: "no_user"
        })
        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
              as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end

    context "with no matching member info" do
      it "creates a new Certification and renders response" do
        params = valid_json_request_attributes.deep_merge({
          member_id: "no_user",
          member_data: { account_email: "neverfound@foo.com" }
        })
        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
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
        params = valid_json_request_attributes.merge({
          certification_requirements: requirement_params.as_json
        })

        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
              as: :json
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
        params = valid_json_request_attributes.merge({
          certification_requirements: certification_requirements.as_json
        })

        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
              as: :json
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
        params = valid_json_request_attributes.merge({
          member_data: member_data.as_json
        })
        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
              as: :json
        }.to change(Certification, :count).by(1)

        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)

        cert = Certification.find(response.parsed_body[:id])
        expect(cert.member_data).to eq(member_data)
      end

      it "accepts activities in member_data" do
        member_data = build(:certification_member_data,
                            :with_full_name,
                            :with_account_email,
                            :with_activities
                           )
        params = valid_json_request_attributes.merge({
          member_data: member_data.as_json
        })
        expect {
          post api_certifications_url,
              params: params,
              headers: auth_headers(params),
              as: :json
        }.to change(Certification, :count).from(0).to(1)

        expect(response).to be_successful
        expect(response).to match_openapi_doc(OPENAPI_DOC)

        cert = Certification.find(response.parsed_body[:id])
        expect(cert.member_data).to eq(member_data)
        expect(cert.member_data.activities).not_to be_nil
        expect(cert.member_data.activities.first.type).to eq("hourly")
        expect(cert.member_data.activities.first.category).to eq("community_service")
        expect(cert.member_data.activities.first.hours).to eq(20)
      end
    end

    context "with activities that create ExParteActivity records" do
      let(:member_id) { "member-789" }
      let(:certification_date) { Date.new(2025, 12, 25) }

      it "creates ExParteActivity records for hourly activities" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "employer" => "Acme Corp",
              "verification_status" => "verified"
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.to change(ExParteActivity, :count).from(0).to(1)
          .and change(Certification, :count).from(0).to(1)

        expect(response).to have_http_status(:created)

        activity = ExParteActivity.last
        expect(activity.member_id).to eq(member_id)
        expect(activity.category).to eq("employment")
        expect(activity.hours).to eq(40)
        expect(activity.source_type).to eq("api")
        expect(activity.source_id).to be_nil
      end

      it "does not create ExParteActivity for income activities" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "income",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.not_to change(ExParteActivity, :count)

        expect(response).to have_http_status(:created)
        expect(Certification.count).to eq(1)
      end

      it "creates ExParteActivity only for hourly activities in mixed types" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            },
            {
              "type" => "income",
              "category" => "employment",
              "hours" => 20,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.to change(ExParteActivity, :count).from(0).to(1)

        expect(response).to have_http_status(:created)

        activity = ExParteActivity.last
        expect(activity.hours).to eq(40)
      end

      it "creates CertificationOrigin record with api source_type" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.to change(CertificationOrigin, :count).from(0).to(1)

        expect(response).to have_http_status(:created)

        origin = CertificationOrigin.last
        expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_API)
        expect(origin.source_id).to be_nil
      end

      it "rolls back certification when ExParteActivity validation fails" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => -10, # Invalid: negative hours
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.not_to change(Certification, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(ExParteActivity.count).to eq(0)
        expect(CertificationOrigin.count).to eq(0)
      end

      it "creates multiple ExParteActivity records for multiple hourly activities" do
        member_data = build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            },
            {
              "type" => "hourly",
              "category" => "community_service",
              "hours" => 10,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
        params = valid_json_request_attributes.merge({
          member_id: member_id,
          member_data: member_data.as_json
        })

        expect {
          post api_certifications_url,
            params: params,
            headers: auth_headers(params),
            as: :json
        }.to change(ExParteActivity, :count).from(0).to(2)

        expect(response).to have_http_status(:created)

        activities = ExParteActivity.where(member_id: member_id).order(:category)
        expect(activities.count).to eq(2)
        expect(activities.first.category).to eq("community_service")
        expect(activities.last.category).to eq("employment")
      end
    end

    context "with invalid parameters" do
      it "does not create a new Certification and renders response" do
        params = invalid_request_attributes
        expect {
          post api_certifications_url,
               params: params,
               headers: auth_headers(params),
               as: :json
        }.not_to change(Certification, :count)

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid cert requirements - lookback_period" do
        params = valid_json_request_attributes.merge({
          certification_requirements: { "lookback_period": 2 }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid cert requirements - array" do
        params = valid_json_request_attributes.merge({
          certification_requirements: { "months_to_be_certified": [ "2025-10-16", "FOOBAR" ] }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid activities - missing required field" do
        params = valid_json_request_attributes.merge({
          member_data: {
            activities: [
              {
                "type": "hourly",
                "category": "community_service"
                # missing required fields: hours, period_start, period_end
              }
            ]
          }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid activities - invalid verification_status" do
        params = valid_json_request_attributes.merge({
          member_data: {
            activities: [
              {
                "type": "hourly",
                "category": "community_service",
                "hours": 20,
                "period_start": Date.today.to_s,
                "period_end": Date.today.to_s,
                "verification_status": "invalid_status"
              }
            ]
          }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid activities - invalid type" do
        params = valid_json_request_attributes.merge({
          member_data: {
            activities: [
              {
                "type": "invalid_type",
                "category": "community_service",
                "hours": 20,
                "period_start": Date.today.to_s,
                "period_end": Date.today.to_s
              }
            ]
          }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end

      it "invalid activities - invalid category" do
        params = valid_json_request_attributes.merge({
          member_data: {
            activities: [
              {
                "type": "hourly",
                "category": "invalid_category",
                "hours": 20,
                "period_start": Date.today.to_s,
                "period_end": Date.today.to_s
              }
            ]
          }
        })
        post api_certifications_url,
             params: params,
             headers: auth_headers(params),
             as: :json

        expect(response).to be_client_error
        expect(response.content_type).to match(a_string_including("application/json"))
        expect(response).to match_openapi_doc(OPENAPI_DOC)
      end
    end
  end
end
