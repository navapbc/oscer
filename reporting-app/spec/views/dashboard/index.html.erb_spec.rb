# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "dashboard/index", type: :view do
  let(:member_data) { build(:certification_member_data, :with_full_name) }
  let(:certification) { create(:certification, member_data: member_data) }
  let(:certification_case) { create(:certification_case, certification: certification) }
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
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)

    assign(:all_certifications, [ certification ])
    assign(:certification, certification)
    assign(:previous_completed_certifications, [])
    assign(:certification_case, certification_case)
    assign(:exemption_application_form, exemption_application_form)
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:member_status, member_status)
    assign(:member_dashboard_compliance, member_dashboard_compliance)

    assign(:current_period, certification.certification_requirements.certification_date)
    assign(:target_hours, HoursComplianceDeterminationService::TARGET_HOURS)
    assign(:period_end_date, certification.certification_requirements.due_date)
    assign(:total_hours_reported, 0)
    assign(:hours_needed, HoursComplianceDeterminationService::TARGET_HOURS)
  end

  context 'with no current exemption or activity report' do
    it 'renders the Figma welcome hero copy' do
      render partial: "dashboard/member_dashboard_welcome_hero"

      expect(rendered).to have_css(".member-dashboard-hero")
      expect(rendered).to have_selector(
        "#member-dashboard-welcome-heading",
        text: I18n.t("dashboard.welcome_hero.heading")
      )
      expect(rendered).to have_text(I18n.t("dashboard.welcome_hero.intro"))
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
      expect(rendered).not_to have_selector(
        'h2',
        text: I18n.t('dashboard.member_compliance.exemption_details_heading')
      )
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
      assign(:activity_report_continue_path,
             activity_report_application_form_path(activity_report_application_form))
    end

    it 'renders a button to continue the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.member_compliance.reporting.continue_button'))
    end

    it 'does not render the exemption get started callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button'))
    end
  end

  context "with denied exemption and hours-only activity report in progress" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end

    let(:hours_based_determination) do
      create(:determination,
             subject: certification,
             outcome: MemberStatus::COMPLIANT,
             decision_method: "automated",
             reasons: [ "hours_reported_compliant" ],
             determination_data: { "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED })
    end
    let(:member_status) do
      MemberStatus.new(
        status: MemberStatus::AWAITING_REPORT,
        determination_method: "automated",
        reason_codes: [],
        human_readable_reason_codes: [],
        latest_determination: hours_based_determination
      )
    end

    before do
      certification_case.update!(exemption_request_approval_status: "denied")
      hours_based_determination
      assign(:member_status, member_status)
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: member_status
             ))
      assign(:activity_report_continue_path,
             activity_report_application_form_path(activity_report_application_form))
    end

    it "renders the Figma hours-only layout (red alert, income-parity cards + table, continue + submit)" do
      render

      expect(rendered).to have_css(".member-dashboard-compliance__alert--error[role='alert']")
      expect(rendered).to have_css(".member-dashboard-compliance__cards--hours-only")
      expect(rendered).not_to have_text(I18n.t("dashboard.member_compliance.progress_cards.income_reported"))
      expect(rendered).to have_selector(
        "a.usa-button.usa-button--outline",
        text: I18n.t("dashboard.member_compliance.reporting.continue_reporting_button")
      )
      expect(rendered).to have_selector(
        "a.usa-button",
        text: I18n.t("dashboard.member_compliance.reporting.submit_button")
      )
      expect(rendered).to have_css(".member-dashboard-compliance__section-header--reporting")
    end

    it "renders the income-parity hours cards and hours activity table" do
      render

      # Hours reported progress card mirrors the income card (label, X/80 value, progress bar)
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.progress_cards.hours_reported"))
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.progress_cards.hours_needed"))
      expect(rendered).to have_css(".member-dashboard-compliance__progress-fill--hours")
      # Hours activity table mirrors the income table footer
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.hours_table.additional_hours_needed"))
      expect(rendered).not_to have_text(I18n.t("dashboard.member_compliance.income_table.additional_income_needed"))
    end
  end

  context "with denied exemption and income-path reporting in progress" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end
    let(:income_determination) do
      create(:determination,
             subject: certification,
             outcome: MemberStatus::COMPLIANT,
             decision_method: "automated",
             reasons: [ "income_reported_compliant" ],
             determination_data: {
               "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
               "satisfied_by" => Determination::SATISFIED_BY_BOTH
             })
    end
    let(:member_status) do
      MemberStatus.new(
        status: MemberStatus::AWAITING_REPORT,
        determination_method: "automated",
        reason_codes: [],
        human_readable_reason_codes: [],
        latest_determination: income_determination
      )
    end

    before do
      certification_case.update!(exemption_request_approval_status: "denied")
      income_determination
      assign(:member_status, member_status)
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: member_status
             ))
      assign(:activity_report_continue_path,
             activity_report_application_form_path(activity_report_application_form))
    end

    it "renders in-progress report status and a yellow income bar before the due date when determination is not_compliant" do
      not_compliant_status = MemberStatus.new(
        status: MemberStatus::NOT_COMPLIANT,
        determination_method: "automated",
        reason_codes: [],
        human_readable_reason_codes: [],
        latest_determination: income_determination
      )
      assign(:member_status, not_compliant_status)
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: not_compliant_status
             ))

      render

      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.report_status.in_progress"))
      expect(rendered).to have_css(".member-dashboard-compliance__progress--income-warning")
      expect(rendered).not_to have_text(I18n.t("dashboard.member_compliance.report_status.not_compliant"))
    end

    it "renders the Figma income in-progress layout (red alert, four cards, continue + submit, table footer)" do
      render

      expect(rendered).to have_css(".member-dashboard-compliance__alert--error[role='alert']")
      expect(rendered).to have_css(".member-dashboard-compliance__cards--income")
      expect(rendered).not_to have_css(".member-dashboard-compliance__cards--hours-only")
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.progress_cards.income_reported"))
      expect(rendered).to have_selector(
        "a.usa-button--outline",
        text: I18n.t("dashboard.member_compliance.reporting.continue_button")
      )
      expect(rendered).to have_selector(
        "a.usa-button",
        text: I18n.t("dashboard.member_compliance.reporting.submit_button")
      )
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.income_table.additional_income_needed"))
      expect(rendered).to have_css(".member-dashboard-compliance__section-header--reporting")
    end
  end

  context "with denied exemption and partial income reported (Figma 7203:4878)" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end
    let(:income_determination) do
      create(:determination,
             subject: certification,
             outcome: MemberStatus::COMPLIANT,
             decision_method: "automated",
             reasons: [ "income_reported_compliant" ],
             determination_data: {
               "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
               "satisfied_by" => Determination::SATISFIED_BY_BOTH
             })
    end
    let(:member_status) do
      MemberStatus.new(
        status: MemberStatus::AWAITING_REPORT,
        determination_method: "automated",
        reason_codes: [],
        human_readable_reason_codes: [],
        latest_determination: income_determination
      )
    end
    let(:lookback_month) { certification.certification_requirements.continuous_lookback_period.start.to_date }

    before do
      certification_case.update!(exemption_request_approval_status: "denied")
      income_determination
      create(:income_activity,
             activity_report_application_form_id: activity_report_application_form.id,
             name: "Greater Boston Food Bank",
             category: "community_service",
             income: 5_000,
             month: lookback_month)
      create(:income_activity,
             activity_report_application_form_id: activity_report_application_form.id,
             name: "Local Public library",
             category: "education",
             income: 5_000,
             month: lookback_month)
      create(:income_activity,
             activity_report_application_form_id: activity_report_application_form.id,
             name: "Neighborhood Pantry",
             category: "community_service",
             income: 3_600,
             month: lookback_month)
      assign(:member_status, member_status)
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: member_status
             ))
      assign(:activity_report_continue_path,
             activity_report_application_form_path(activity_report_application_form))
    end

    it "renders partial income across cards and the activity table (Figma frame 8)" do
      render

      expect(rendered).to match(/\$136\s*\/\s*\$580/)
      expect(rendered).to have_text("23% of requirement met")
      expect(rendered).to have_text("$444")
      expect(rendered).to have_text("Greater Boston Food Bank")
      expect(rendered).to have_text("Local Public library")
      expect(rendered).to have_text("Neighborhood Pantry")
      expect(rendered).to have_selector('[role="progressbar"][aria-valuenow="23"]')
      expect(rendered).to have_selector("tfoot", text: "$136.00")
      expect(rendered).to have_selector("tfoot", text: "$444.00")
    end
  end

  context "with an in-progress activity report and income summary" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end
    let(:member_dashboard_compliance) do
      MemberDashboardComplianceService.build(
        certification: certification,
        activity_report_application_form: activity_report_application_form,
        certification_case: certification_case,
        exemption_application_form: exemption_application_form,
        member_status: member_status
      ).tap do |read_model|
        allow(read_model).to receive(:show_income_summary).and_return(true)
      end
    end

    before do
      lookback_month = certification.certification_requirements.continuous_lookback_period.start.to_date
      create(:income_activity,
             activity_report_application_form_id: activity_report_application_form.id,
             name: "Greater Boston Food Bank",
             month: lookback_month)
      assign(:member_dashboard_compliance, member_dashboard_compliance)
      assign(:activity_report_continue_path,
             activity_report_application_form_path(activity_report_application_form))
    end

    it "renders income progress cards and the income table with organization names" do
      render

      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.progress_cards.income_reported"))
      expect(rendered).to have_text("Greater Boston Food Bank")
    end
  end

  context "with an in-progress exemption request" do
    let(:exemption_application_form) do
      create(:exemption_application_form, certification_case_id: certification_case.id)
    end

    it 'renders a button to continue the exemption request' do
      render
      expect(rendered).to have_selector('.member-dashboard-compliance__onboarding-cta a.usa-button',
                                         text: I18n.t('dashboard.member_compliance.exemption_alerts.draft.button'))
    end

    it 'renders the Figma exemption-draft layout (blue alert, CTA, about reporting)' do
      render

      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.draft.title'))
      expect(rendered).to have_css('.member-dashboard-compliance__onboarding')
      expect(rendered).to have_css('.member-dashboard-compliance__alert--info[role="alert"]')
      expect(rendered).to have_css('.member-dashboard-compliance__about-reporting')
      expect(rendered).not_to have_selector(
        'h2',
        text: I18n.t('dashboard.member_compliance.exemption_details_heading')
      )
    end

    it 'does not render the exemption get started callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button'))
    end
  end

  context "with a submitted activity report" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    it "renders member compliance report status under review subcopy" do
      render
      expect(rendered).to have_text(
        I18n.t("dashboard.member_compliance.progress_cards.report_status_subcopy.under_review")
      )
    end

    it "does not render continue or submit activity report actions" do
      render
      expect(rendered).not_to have_selector("a", text: I18n.t("dashboard.member_compliance.reporting.continue_button"))
      expect(rendered).not_to have_selector("a", text: I18n.t("dashboard.member_compliance.reporting.submit_button"))
    end

    it "has a button to view the submitted activity report" do
      render
      expect(rendered).to have_selector("a", text: I18n.t("dashboard.activity_report_submitted.view_activity_report_button"))
    end
  end

  context "with a submitted exemption request" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    it 'renders exemption under review messaging' do
      render
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.title'))
    end

    it 'renders the Figma under-review layout (review alert, history, footer; no section heading)' do
      render

      expect(rendered).not_to have_selector(
        'h2',
        text: I18n.t('dashboard.member_compliance.exemption_details_heading')
      )
      expect(rendered).to have_css('.member-dashboard-compliance__exemption-status')
      expect(rendered).to have_css('.member-dashboard-compliance__alert--review[role="alert"]')
      expect(rendered).to have_css('.member-dashboard-compliance__history')
      expect(rendered).to have_css('.member-dashboard-compliance__history-entry')
      expect(rendered).to have_text(I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.footer'))
      expect(rendered).not_to have_text(I18n.t('dashboard.member_compliance.reporting.heading'))
    end

    it 'has a button to view the submitted exemption request above the reporting section' do
      render
      view_button = I18n.t('dashboard.exemption_submitted.view_exemption_button')
      reporting_heading = I18n.t('dashboard.member_compliance.reporting.heading')
      expect(rendered).to have_selector('a', text: view_button)
      expect(rendered.index(view_button)).to be < rendered.index(reporting_heading) if rendered.include?(reporting_heading)
    end
  end

  context "with an approved activity report" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    before do
      certification_case.update!(activity_report_approval_status: "approved")
      create(:determination,
             subject: certification,
             outcome: "compliant",
             decision_method: "manual",
             reasons: [ "hours_reported_compliant" ])
      assign(:hours_needed, 0)
      assign(:total_hours_reported, HoursComplianceDeterminationService::TARGET_HOURS)
      approved_status = MemberStatusService.determine(certification)
      assign(:member_status, approved_status)
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: approved_status
             ))
    end

    it "renders compliant report status subcopy" do
      render
      expect(rendered).to have_text(
        I18n.t("dashboard.member_compliance.progress_cards.report_status_subcopy.compliant")
      )
    end

    it "has a button to view the activity report" do
      render
      expect(rendered).to have_selector("a", text: I18n.t("dashboard.activity_report_approved.view_activity_report_button"))
    end
  end

  context "with a denied activity report" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    before do
      certification_case.update!(activity_report_approval_status: "denied")
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: MemberStatusService.determine(certification)
             ))
    end

    it "renders the activity report denial state alert and view button" do
      render

      expect(rendered).to have_selector(
        "h3",
        text: I18n.t("dashboard.activity_report_denied.heading")
      )
      expect(rendered).to have_selector(
        "a",
        text: I18n.t("dashboard.activity_report_denied.view_activity_report_button")
      )
    end
  end

  context "with a denied exemption request" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    before do
      certification_case.update!(exemption_request_approval_status: "denied")
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: MemberStatusService.determine(certification)
             ))
    end

    it "renders the Figma not-exempt start-reporting layout (red alert, history, start CTA)" do
      render

      expect(rendered).to have_selector(
        "h2",
        text: I18n.t("dashboard.member_compliance.exemption_details_heading")
      )
      expect(rendered).to have_selector(
        "h3",
        text: I18n.t("dashboard.member_compliance.exemption_alerts.denied.title")
      )
      expect(rendered).to have_css(".member-dashboard-compliance__alert--error[role='alert']")
      expect(rendered).to have_css(".member-dashboard-compliance__history")
      expect(rendered).to have_text(I18n.t("dashboard.member_compliance.reporting.heading"))
      expect(rendered).to have_selector(
        "a.usa-button",
        text: I18n.t("dashboard.member_compliance.reporting.start_button")
      )
      expect(rendered).not_to have_selector("h3", text: I18n.t("dashboard.exemption_denied.heading"))
      expect(rendered).not_to have_selector(
        "a",
        text: I18n.t("dashboard.member_compliance.reporting.continue_button")
      )
    end

    it "has a button to view the exemption request above the reporting section" do
      render
      view_button = I18n.t("dashboard.exemption_denied.view_exemption_button")
      reporting_heading = I18n.t("dashboard.member_compliance.reporting.heading")
      expect(rendered).to have_selector("a", text: view_button)
      expect(rendered.index(view_button)).to be < rendered.index(reporting_heading)
    end
  end

  context "with an approved exemption request" do
    let(:exemption_application_form) do
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    before do
      certification_case.update!(exemption_request_approval_status: "approved")
      create(:determination,
             subject: certification,
             outcome: "exempt",
             decision_method: "manual",
             reasons: [ "exemption_request_compliant" ],
             determination_data: { "exemption_type" => exemption_application_form.exemption_type })
      assign(:member_dashboard_compliance,
             MemberDashboardComplianceService.build(
               certification: certification,
               activity_report_application_form: activity_report_application_form,
               certification_case: certification_case,
               exemption_application_form: exemption_application_form,
               member_status: MemberStatusService.determine(certification)
             ))
    end

    it 'renders the exempt eligibility alert' do
      render
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.approved.title'))
    end

    it 'renders the Figma exempt layout (heading, green alert, history, no reporting)' do
      render

      expect(rendered).to have_selector(
        'h2',
        text: I18n.t('dashboard.member_compliance.exemption_details_heading')
      )
      expect(rendered).to have_css('.member-dashboard-compliance__exemption-status')
      expect(rendered).to have_css('.member-dashboard-compliance__alert--success[role="alert"]')
      expect(rendered).to have_css('.member-dashboard-compliance__history')
      expect(rendered).to have_css('.member-dashboard-compliance__badge--exempt')
      expect(rendered).not_to have_text(I18n.t('dashboard.member_compliance.reporting.heading'))
      expect(rendered).not_to have_text(I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.footer'))
    end

    it 'has a button to view the certification' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_approved.view_certification_button'))
    end
  end

  context "with previous certifications" do
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
end
