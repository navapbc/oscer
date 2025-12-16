# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)

    assign(:all_certifications, [
      certification
    ])
    assign(:certification, certification)
    assign(:certification_case, certification_case)

    # Hours compliance data required by the dashboard partials
    assign(:current_period, certification.certification_requirements.certification_date)
    assign(:target_hours, HoursComplianceDeterminationService::TARGET_HOURS)
    assign(:period_end_date, certification.certification_requirements.due_date)
    assign(:total_hours_reported, 0)
    assign(:hours_needed, HoursComplianceDeterminationService::TARGET_HOURS)
  end

  context 'with no current exemption or activity report' do
    it 'renders the current period header' do
      render
      expect(rendered).to have_selector('h2', text: /Current period:/)
    end

    it 'renders buttons to report activities or request exemption' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.request_exemption_button'))
    end

    it 'renders "get started" callout' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with an in-progress activity report" do
    before do
      assign(:activity_report_application_form, create(:activity_report_application_form, certification_case_id: certification_case.id))
    end

    it 'renders a button to continue the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.activity_report.continue_report_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with an in-progress exemption request" do
    before do
      assign(:exemption_application_form, create(:exemption_application_form, certification_case_id: certification_case.id))
    end

    it 'renders a button to continue the exemption request' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.exemption_request.continue_request_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with a submitted activity report" do
    let (:activity_report_application_form) { create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:activity_report_application_form, activity_report_application_form)
      assign(:certification_case, certification_case)
    end

    it 'renders a message that the activity report is under review' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.activity_report_submitted.intro'))
    end

    it 'has a button to view the submitted activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_submitted.view_activity_report_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with a submitted exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)
    end

    it 'renders a message that the exemption request is under review' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.exemption_submitted.intro'))
    end

    it 'has a button to view the submitted exemption request' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_submitted.view_exemption_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with an approved activity report" do
    let(:activity_report_application_form) { create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:activity_report_application_form, activity_report_application_form)
      assign(:certification_case, certification_case)
      # Set hours_needed to 0 to show requirements met state
      assign(:hours_needed, 0)
      assign(:total_hours_reported, HoursComplianceDeterminationService::TARGET_HOURS)

      certification_case.activity_report_approval_status = "approved"
    end

    it 'renders a message that the requirements are met' do
      render
      expect(rendered).to have_content(/You have met the requirement/)
    end

    it 'has a button to view the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_approved.view_activity_report_button'))
    end

    it 'renders the blue banner section' do
      # The approved activity report view intentionally shows the blue banner
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with an approved exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)

      certification_case.exemption_request_approval_status = "approved"
    end

    it 'renders a message that the exemption request is approved' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.exemption_approved.intro'))
    end

    it 'has a button to view the certification' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_approved.view_certification_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.get_started.button'))
    end
  end

  context "with previous certifications" do
    let(:older_certification) { create(:certification) }

    before do
      assign(:all_certifications, [
        certification,
        older_certification
      ])
    end

    it 'renders a section for previous certifications' do
      render
      expect(rendered).to have_selector('h2', text: I18n.t('dashboard.index.previous_certifications.title'))
    end

    it 'renders a button to review previous certifications' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.index.previous_certifications.review_previous_certifications_button'))
    end
  end

  context "without previous certifications" do
    it 'does not render the previous certifications section from index' do
      render
      # The index.html.erb only shows previous certifications section when there are >1 certifications
      # But the new_certification partial has its own "Previously completed requirements" section
      expect(rendered).not_to have_selector('h2', text: I18n.t('dashboard.index.previous_certifications.title'))
    end
  end
end
