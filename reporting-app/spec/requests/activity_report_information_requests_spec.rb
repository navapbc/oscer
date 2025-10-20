# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/activity_report_information_requests", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:application_form) { create(:activity_report_application_form, user_id: user.id) }
  let(:information_request) { build(:activity_report_information_request, application_form_id: application_form.id, application_form_type: application_form.class.name) }

  before do
    information_request.save!
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /edit" do
    context "when the user is authorized" do
      it "renders a successful response" do
        get edit_activity_report_information_request_url(information_request)
        expect(response).to be_successful
      end
    end

    context "when the user is not authorized" do
      before do
        login_as other_user
      end

      it "raises an authorization error" do
        get edit_activity_report_information_request_url(information_request)
        expect(response).to be_client_error
      end
    end
  end

  describe "PATCH /update" do
    let(:valid_attributes) { { member_comment: "Here is the information you requested." } }

    context "with valid parameters" do
      it "updates the requested information_request" do
        patch activity_report_information_request_url(information_request), params: { activity_report_information_request: valid_attributes }
        information_request.reload
        expect(information_request.member_comment).to eq("Here is the information you requested.")
      end

      it "redirects to the dashboard" do
        patch activity_report_information_request_url(information_request), params: { activity_report_information_request: valid_attributes }
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "when the user is not authorized" do
      before do
        login_as other_user
      end

      it "raises an authorization error" do
        patch activity_report_information_request_url(information_request), params: { activity_report_information_request: valid_attributes }
        expect(response).to be_client_error
      end
    end
  end
end
