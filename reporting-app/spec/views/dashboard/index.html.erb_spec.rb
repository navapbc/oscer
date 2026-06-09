# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  let(:member_data) { build(:certification_member_data, :with_full_name) }
  let(:certification) { create(:certification, member_data: member_data) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:exemption_application_form) { nil }
  let(:activity_report_application_form) { nil }
  let(:member_status) { MemberStatusService.determine(certification) }
  let(:member_dashboard_compliance) do
    MemberDashboardComplianceService.build(
      certification: certification,
      activity_report_application_form: activity_report_application_form,
      certification_case: certification_case,
      exemption_application_form: exemption_application_form,
      member_status: member_status
    )
  end

  before do
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)

    assign(:all_certifications, [
      certification
    ])
    assign(:certification, certification)
    assign(:previous_completed_certifications, [])
    assign(:certification_case, certification_case)
    assign(:exemption_application_form, exemption_application_form)
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:member_status, member_status)
    assign(:member_dashboard_compliance, member_dashboard_compliance)

    # Hours compliance data required by the dashboard partials
    assign(:current_period, certification.certification_requirements.certification_date)
    assign(:target_hours, HoursComplianceDeterminationService::TARGET_HOURS)
    assign(:period_end_date, certification.certification_requirements.due_date)
    assign(:total_hours_reported, 0)
    assign(:hours_needed, HoursComplianceDeterminationService::TARGET_HOURS)
  end

  context 'with no current exemption or activity report' do
    it 'renders the Figma welcome hero copy via the dashboard layout banner' do
      render inline: <<~ERB.squish, type: :erb
        <%= content_for :banner do %>
          <section class="member-dashboard-hero" aria-labelledby="member-dashboard-welcome-heading">
            <div class="grid-container">
              <h1 id="member-dashboard-welcome-heading" class="member-dashboard-hero__heading">
                <%= t("dashboard.welcome_hero.heading") %>
              </h1>
              <p class="member-dashboard-hero__intro">
                <%= t("dashboard.welcome_hero.intro") %>
              </p>
            </div>
          </section>
        <% end %>
        <%= yield :banner %>
      ERB

      expect(rendered).to have_css(".member-dashboard-hero")
      expect(rendered).to have_selector(
        "#member-dashboard-welcome-heading",
        text: I18n.t("dashboard.welcome_hero.heading")
      )
      expect(rendered).to have_text(I18n.t("dashboard.welcome_hero.intro"))
    end

    it 'renders the member greeting' do
      render
      expect(rendered).to have_css(".member-dashboard-greeting")
    end

    it 'renders the exemption get-started alert' do
      render
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.title'))
    end

    it 'renders the Figma get-started layout (blue alert, CTA, about reporting)' do
      render

      expect(rendered).to have_css('.member-dashboard-compliance__onboarding')
      expect(rendered).to have_css('.member-dashboard-compliance__alert--info[role="alert"]')
      expect(rendered).to have_css('.member-dashboard-compliance__about-reporting')
    end

    it 'renders the get started button for the exemption screener' do
      render
      expect(rendered).to have_selector('.member-dashboard-compliance__onboarding-cta a.usa-button',
                                         text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button'))
    end

    it 'does not render the legacy report activities buttons' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
    end

    it 'does not render previous certifications when the member has only one certification' do
      render
      expect(rendered).not_to have_selector(
        'h2',
        text: I18n.t('dashboard.index.previous_certifications.title')
      )
    end
  end

  context "with an in-progress activity report" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end

    before do
      assign(:activity_report_application_form, activity_report_application_form)
    end

    it 'renders a button to continue the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.activity_report.continue_report_button'))
    end

    it 'does not render the Figma get started callout' do
      render
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
    end
  end

  context "with an in-progress exemption request" do
    let(:exemption_application_form) do
      create(:exemption_application_form, certification_case_id: certification_case.id)
    end

    before do
      assign(:exemption_application_form, exemption_application_form)
    end

    it 'renders a button to continue the exemption request' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.exemption_request.continue_request_button'))
    end

    it 'does not render the Figma get started callout' do
      render
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
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
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
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
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
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

    it 'does not render the Figma get started callout' do
      render
      expect(rendered).not_to have_css('.member-dashboard-compliance__onboarding')
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
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
    end
  end

  context "with a denied activity report" do
    let(:activity_report_application_form) { create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:activity_report_application_form, activity_report_application_form)
      assign(:certification_case, certification_case)
      # Set hours_needed to 0 to show requirements met state
      assign(:hours_needed, 0)
      assign(:total_hours_reported, HoursComplianceDeterminationService::TARGET_HOURS)

      certification_case.activity_report_approval_status = "denied"
    end

    it 'renders a message that the activity report is denied' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.activity_report_denied.intro'))
    end

    it 'has a button to view the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_denied.view_activity_report_button'))
    end
  end

  context "with a denied exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)

      certification_case.exemption_request_approval_status = "denied"
    end

    it 'renders a message that the exemption request is denied' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.exemption_denied.intro'))
    end

    it 'has a button to view the exemption' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_denied.view_exemption_button'))
    end

    it 'renders button to report activities' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
    end

    it 'does not render the "get started" callout' do
      render
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
    end

    context "with an in-progress activity report" do
      before do
        assign(:activity_report_application_form, create(:activity_report_application_form, certification_case_id: certification_case.id))
      end

      it 'renders a button to continue the activity report' do
        render
        expect(rendered).to have_selector('a', text: I18n.t('dashboard.new_certification.activity_report.continue_report_button'))
      end
    end
  end

  context "with a completed prior certification period" do
    let(:older_certification) { create(:certification, member_data: member_data) }

    before do
      create(:certification_case, certification: older_certification)
      create(:determination,
             subject: older_certification,
             outcome: "compliant",
             decision_method: "manual",
             reasons: [ "hours_reported_compliant" ])
      older_certification.update!(created_at: 2.months.ago)
      certification.update!(created_at: 1.day.ago)
      assign(:all_certifications, [ certification, older_certification ])
      assign(:previous_completed_certifications,
             MemberStatusService.previous_completed_certifications(
               [ certification, older_certification ],
               current_certification: certification
             ))
    end

    it 'renders a section for previous certifications' do
      render
      expect(rendered).to have_selector('h2', text: I18n.t('dashboard.index.previous_certifications.title'))
    end

    it 'renders previous certifications only once' do
      render
      title = I18n.t('dashboard.index.previous_certifications.title')
      expect(rendered.scan(title).length).to eq(1)
    end

    it 'renders a button to review previous certifications' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.index.previous_certifications.review_previous_certifications_button'))
    end
  end

  context "with an older certification still in progress" do
    let(:older_certification) { create(:certification, member_data: member_data) }

    before do
      create(:certification_case, certification: older_certification)
      older_certification.update!(created_at: 2.months.ago)
      certification.update!(created_at: 1.day.ago)
      assign(:all_certifications, [ certification, older_certification ])
      assign(:previous_completed_certifications,
             MemberStatusService.previous_completed_certifications(
               [ certification, older_certification ],
               current_certification: certification
             ))
    end

    it "does not render previous certifications" do
      render
      expect(rendered).not_to have_selector(
        'h2',
        text: I18n.t('dashboard.index.previous_certifications.title')
      )
    end
  end

  context "without previous certifications" do
    it 'does not render the previous certifications section from index' do
      render
      expect(rendered).not_to have_selector('h2', text: I18n.t('dashboard.index.previous_certifications.title'))
    end
  end
end
