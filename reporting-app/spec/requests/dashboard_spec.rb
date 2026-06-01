# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/dashboard", type: :request do
  include Warden::Test::Helpers

  let(:member_data) { build(:certification_member_data, :with_account_email) }
  let!(:certification) { create(:certification, member_data: member_data) }
  let(:user) { create(:user, email: member_data.account_email) }
  let(:certification_case) { create(:certification_case, certification: certification) }

  before do
    allow(Strata::EventManager).to receive(:publish)
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /" do
    it "does not fail if no application form" do
      get "/dashboard"
      expect(response).to be_ok
    end

    it "sets the activity report application form" do
      form = create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get "/dashboard"
      expect(response.body).to include(activity_report_application_form_path(form))
    end

    it "sets the in-progress activity report application form if more than one form" do
      submitted_form = create(:activity_report_application_form, :with_submitted_status, user_id: user.id, certification_case_id: certification_case.id)
      form = create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get "/dashboard"
      expect(response.body).not_to include(activity_report_application_form_path(submitted_form))
      expect(response.body).to include(activity_report_application_form_path(form))
    end

    it "sets the exemption application form" do
      form = create(:exemption_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get "/dashboard"
      expect(response.body).to include(exemption_application_form_path(form))
    end

    it "sets the in-progress exemption application form if more than one form" do
      submitted_form = create(:exemption_application_form, :with_submitted_status, user_id: user.id, certification_case_id: certification_case.id)
      form = create(:exemption_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get "/dashboard"
      expect(response.body).not_to include(exemption_application_form_path(submitted_form))
      expect(response.body).to include(exemption_application_form_path(form))
    end
  end
end
