# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/certifications", type: :request do
  include Warden::Test::Helpers

  let(:staff_user) { create(:user, email: "staff@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:member_user) { create(:user, email: "member@example.com", uid: SecureRandom.uuid, provider: "login.gov") }

  let(:valid_html_request_attributes) {
    {
      member_id: "foobar",
      member_data: "{\"account_email\": \"#{member_user.email}\"}",
      certification_requirements: build(:certification_certification_requirement_params, :with_direct_params).attributes.compact.to_json
    }
  }

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

  before do
    login_as staff_user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /index" do
    it "renders a successful response with a Certification" do
      create(:certification)
      get certifications_url
      expect(response).to be_successful
    end

    it "renders a successful response with multiple Certifications" do
      create_list(:certification, 10)
      get certifications_url
      expect(response).to be_successful
    end

    it "renders a successful response without Certifications" do
      get certifications_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      certification = create(:certification)
      get certification_url(certification)
      expect(response).to be_successful
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        {
          member_id: "updated"
        }
      }

      it "updates the requested certification" do
        certification = create(:certification)
        patch certification_url(certification),
              params: { certification: new_attributes }, headers: valid_headers, as: :json
        certification.reload
        expect(certification.member_id).to eq("updated")
      end

      it "renders a HTML response with the certification" do
        certification = create(:certification)
        patch certification_url(certification),
              params: { certification: new_attributes }, headers: valid_headers, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid parameters" do
      it "renders a JSON response with errors for the certification" do
        certification = create(:certification)
        patch certification_url(certification),
              params: { certification: invalid_request_attributes }, headers: valid_headers, as: :json
        expect(response).to be_client_error
      end
    end
  end
end
