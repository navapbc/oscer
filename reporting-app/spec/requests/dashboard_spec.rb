# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/dashboard", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }

  before do
    login_as user
    # Stub determination-producing services so factory/event-listener chains don't create
    # determinations as a side effect of building a +CertificationCase+ (mirrors the read-model spec).
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  after do
    Warden.test_reset!
  end

  describe "GET /index" do
    it "renders a successful response with no certification" do
      get dashboard_path
      expect(response).to be_successful
    end

    it "renders a successful response with no forms, but certification" do
      certification = create(:certification, :connected_to_email, email: user.email)
      create(:certification_case, certification: certification)

      get dashboard_path
      expect(response).to be_successful
    end

    it "renders successfully when a certification exists but no CertificationCase has been created" do
      create(:certification, :connected_to_email, email: user.email)

      get dashboard_path
      expect(response).to be_successful
    end

    it "assigns @member_dashboard_compliance from the read model" do
      certification = create(:certification, :connected_to_email, email: user.email)
      kase = create(:certification_case, certification: certification)
      kase.update!(business_process_current_step: CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)

      get dashboard_path
      expect(response).to be_successful
      expect(assigns(:member_dashboard_compliance)).to be_a(MemberDashboardCompliance)
      expect(assigns(:member_dashboard_compliance).report_status_token).to eq(MemberStatus::DASHBOARD_REPORT_IN_PROGRESS)
    end

    it "does not query ExternalIncomeActivity for an AWAITING_REPORT member (income fields are lazy)" do
      certification = create(:certification, :connected_to_email, email: user.email)
      kase = create(:certification_case, certification: certification)
      kase.update!(business_process_current_step: CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      allow(ExternalIncomeActivity).to receive(:for_member).and_call_original

      get dashboard_path

      expect(response).to be_successful
      # Current dashboard partials only consume hours fields; income aggregation must stay lazy
      # until the OSCER-480 consumer ships.
      expect(ExternalIncomeActivity).not_to have_received(:for_member)
    end

    it "resolves the form-bearing CertificationCase when multiple cases share a certification_id" do
      certification = create(:certification, :connected_to_email, email: user.email)
      # +certification_case_factory+ uses +find_or_create_by!+; use +CertificationCase.create!+ directly
      # to seed two rows for the same certification, then attach an +ActivityReportApplicationForm+ to
      # the second one — the tie-break should pick the form-bearing case.
      CertificationCase.create!(certification_id: certification.id, business_process_current_step: "report_activities")
      form_bearing = CertificationCase.create!(certification_id: certification.id, business_process_current_step: "report_activities")
      ActivityReportApplicationForm.create!(certification_case_id: form_bearing.id)

      get dashboard_path

      expect(response).to be_successful
      expect(assigns(:certification_case).id).to eq(form_bearing.id)
    end
  end
end
