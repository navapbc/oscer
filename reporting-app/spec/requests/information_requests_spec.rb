# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/information_requests", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:certification_case) { create(:certification_case) }
  let(:application_form) do
    build(
      form_type,
      certification_case_id: certification_case.id,
    )
  end

  before do
    application_form.save!
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
    let(:information_request) do
      information_request_class.create(
        application_form_id: application_form.id,
        application_form_type: application_form.class.name,
        staff_comment: "Please provide more details."
      )
    end

    context "when viewing an exemption claim information request" do
      let(:form_type) { :exemption_application_form }
      let(:information_request) do
        ExemptionInformationRequest.create!(
          application_form_id: application_form.id,
          application_form_type: application_form.class.name,
          staff_comment: "Please provide more details."
        )
      end

      it "renders a successful response" do
        get information_request_path(information_request)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when viewing an activity report information request" do
      let(:form_type) { :activity_report_application_form }
      let(:information_request) do
        ActivityReportInformationRequest.create!(
          application_form_id: application_form.id,
          application_form_type: application_form.class.name,
          staff_comment: "Please provide more details."
        )
      end

      it "renders a successful response" do
        get information_request_path(information_request)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
