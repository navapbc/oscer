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

  # Rebuild the compliance read model after a context mutates case/determination state.
  # +exemption_flow_state+ is computed eagerly at build time, so the shared outer `before`
  # would otherwise capture the pre-mutation state.
  def reassign_compliance_read_model
    member_status = MemberStatusService.determine(certification)
    assign(:member_status, member_status)
    assign(:member_dashboard_compliance,
           MemberDashboardComplianceService.build(
             certification: certification,
             certification_case: certification_case,
             exemption_application_form: exemption_application_form,
             activity_report_application_form: activity_report_application_form,
             member_status: member_status
           ))
  end

  def assign_previous_completed_certification_period
    older_certification = create(:certification, member_data: member_data)
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
      expect(rendered).to have_css('.member-dashboard-compliance__alert--info[role="region"]')
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
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.member_compliance.reporting.continue_report_button'))
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
      reassign_compliance_read_model
    end

    it 'renders the blue "draft in progress" alert' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--info[role="region"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.draft.title'))
      expect(rendered).to have_text(I18n.t('dashboard.member_compliance.exemption_alerts.draft.body'))
    end

    it 'renders the Figma draft layout (onboarding alert, CTA, about reporting)' do
      render

      expect(rendered).to have_css('.member-dashboard-compliance__onboarding')
      expect(rendered).to have_css('.member-dashboard-compliance__about-reporting')
    end

    it 'renders a button to continue the exemption request' do
      render
      expect(rendered).to have_link(
        I18n.t('dashboard.member_compliance.exemption_alerts.draft.button'),
        href: exemption_screener_may_qualify_path(
          exemption_type: exemption_application_form.exemption_type,
          certification_case_id: certification_case.id
        )
      )
      expect(rendered).to have_selector('.member-dashboard-compliance__onboarding-cta a.usa-button')
    end

    it 'does not render the "Exemption details" heading' do
      render
      expect(rendered).not_to have_selector('h2', text: I18n.t('dashboard.member_compliance.exemption_details_heading'))
    end

    it 'does not render exemption history' do
      render
      expect(rendered).not_to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_request_history_heading'))
    end

    it 'does not render a reporting section' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
      expect(rendered).not_to have_selector('h2', text: I18n.t('dashboard.member_compliance.reporting.heading'))
    end

    it 'does not render the legacy compliance status block' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.exemption_request.continue_request_button'))
    end

    it 'does not render the Figma get started callout' do
      render
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button')
      )
    end

    context "with an in-progress activity report also present" do
      let(:activity_report_application_form) do
        create(:activity_report_application_form, certification_case_id: certification_case.id)
      end

      before do
        assign(:activity_report_application_form, activity_report_application_form)
        reassign_compliance_read_model
      end

      it 'renders the exemption draft frame only (no activity-report continue CTA)' do
        render
        expect(rendered).to have_link(
          I18n.t('dashboard.member_compliance.exemption_alerts.draft.button'),
          href: exemption_screener_may_qualify_path(
            exemption_type: exemption_application_form.exemption_type,
            certification_case_id: certification_case.id
          )
        )
        expect(rendered).not_to have_selector(
          'a',
          text: I18n.t('dashboard.member_compliance.reporting.continue_report_button')
        )
        expect(rendered).not_to have_selector(
          'a',
          text: I18n.t('dashboard.new_certification.activity_report.continue_report_button')
        )
      end
    end
  end

  context "with a submitted activity report" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end
    let(:lookback) { certification.certification_requirements.continuous_lookback_period }
    let(:hours_table) { ".member-dashboard-compliance__table--hours" }
    let(:income_table) { ".member-dashboard-compliance__table--income" }

    def create_external_hourly(hours: 30)
      create(:external_hourly_activity, member_id: certification.member_id, category: "employment",
             hours: hours, period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month)
    end

    def create_external_income(gross_income: 300)
      create(:external_income_activity, member_id: certification.member_id, category: "employment",
             gross_income: gross_income, period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month)
    end

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

    context "with reported activities" do
      before do
        create_external_hourly
        create_external_income
        reassign_compliance_read_model
      end

      it "renders activity tables under the month-based heading" do
        render
        month = I18n.l(certification.certification_requirements.certification_date, format: :month_year)
        expect(rendered).to have_selector(
          "h3",
          text: I18n.t("dashboard.member_compliance.activity_report_title", period: month)
        )
        expect(rendered).to have_css(hours_table)
        expect(rendered).to have_css(income_table)
        expect(rendered.index("member-dashboard-compliance__table--hours"))
          .to be < rendered.index("member-dashboard-compliance__table--income")
      end
    end

    context "with reported activities on the submitted report (OSCER-642 + OSCER-690)" do
      let(:lookback) { certification.certification_requirements.continuous_lookback_period }
      let(:activity_report_application_form) do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        activity = create(:hourly_activity, activity_report_application_form_id: form.id, name: "Submitted Employer",
               category: "employment", hours: 25, month: lookback.start.to_date)
        activity.supporting_documents.attach(
          fixture_file_upload("spec/fixtures/files/test_document_1.pdf", "application/pdf")
        )
        form
      end

      before do
        create(:external_hourly_activity, member_id: certification.member_id, category: "employment",
               hours: 30, period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month)
        assign(:activity_report_application_form, activity_report_application_form)
        reassign_compliance_read_model
      end

      it "renders compliance summary tables, line items, and a supporting-document download link" do
        render
        period = I18n.l(certification.certification_requirements.certification_date, format: :month_year)
        expect(rendered).to have_selector("h3", text: I18n.t("dashboard.member_compliance.activity_report_title", period: period))
        expect(rendered).to have_css(".member-dashboard-compliance__table--hours")
        expect(rendered).to have_selector("h2#member-compliance-line-items-heading",
                                          text: I18n.t("dashboard.member_compliance.activity_line_items.heading"))
        expect(rendered).to have_selector(".member-dashboard-compliance__line-items td", text: "Submitted Employer")
        expect(rendered).to have_link("test_document_1.pdf", href: %r{/rails/active_storage/blobs/})
      end
    end
  end

  context "with a submitted exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)
    end

    it 'renders the blue "under review" alert' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--review[role="region"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.title'))
      expect(rendered).to have_text(I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.footer'))
    end

    it 'renders the exemption history with an UNDER REVIEW badge' do
      render
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_request_history_heading'))
      expect(rendered).to have_selector('.member-dashboard-compliance__badge--under-review',
                                        text: I18n.t('dashboard.member_compliance.exemption_badges.under_review'))
    end

    it 'does not render the "Exemption details" heading' do
      render
      expect(rendered).not_to have_selector('h2', text: I18n.t('dashboard.member_compliance.exemption_details_heading'))
    end

    it 'has a button to view the submitted exemption request' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_submitted.view_exemption_button'))
    end

    it 'does not render a reporting section' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
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

      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 85, hours_by_category: {}, hours_by_source: { external: 85, activity: 0 },
        external_hourly_activity_ids: [], activity_ids: []
      })
      ReviewActivityReportTask.find_by(application_form: activity_report_application_form).completed!
      certification_case.accept_activity_report(nil, activity_report_application_form)
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

    context "with a completed prior certification period (OSCER-717)" do
      before { assign_previous_completed_certification_period }

      it 'renders the previously-completed requirements section exactly once after the approved-frame CTA' do
        render
        title = I18n.t('dashboard.index.previous_certifications.title')
        view_report_label = I18n.t('dashboard.activity_report_approved.view_activity_report_button')

        expect(rendered.scan(title).length).to eq(1)
        expect(rendered).to have_css('section[aria-labelledby="previous-certifications-heading"]')
        expect(rendered).to have_selector('h2#previous-certifications-heading', text: title)
        expect(rendered.index(view_report_label)).to be < rendered.index(title)
        expect(rendered).not_to have_css('.member-dashboard-previous-certifications')
      end
    end
  end

  context "with an approved activity report — \"Report this month's activities\" gating (OSCER-718)" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end
    let(:get_started_section) { 'section[aria-label="Get started"]' }

    # Drive the form to an "approved" flow_status without closing the case, so case status and
    # due date can be varied independently (the real accept_activity_report path always closes).
    def approve_report!
      ReviewActivityReportTask.find_by(application_form: activity_report_application_form).completed!
      certification_case.update!(activity_report_approval_status: "approved")
    end

    before do
      assign(:activity_report_application_form, activity_report_application_form)
      assign(:certification_case, certification_case)
    end

    context "when the case is open and the reporting due date has not passed" do
      before { approve_report! }

      it "shows the get-started block" do
        render
        expect(rendered).to have_css(get_started_section)
      end
    end

    context "when the case is open but the reporting due date has passed" do
      let(:certification) do
        create(:certification, member_data: member_data,
               certification_requirements: build(:certification_certification_requirements, due_date: 1.day.ago.to_date))
      end

      before { approve_report! }

      it "hides the get-started block but keeps the rest of the approved frame" do
        render
        expect(rendered).not_to have_css(get_started_section)
        expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_approved.view_activity_report_button'))
      end
    end

    context "when the case is closed" do
      before do
        approve_report!
        certification_case.close!
      end

      it "hides the get-started block regardless of the due date, keeping the rest of the approved frame" do
        render
        expect(rendered).not_to have_css(get_started_section)
        expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_approved.view_activity_report_button'))
      end
    end
  end

  context "with an approved exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, :incarceration, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)

      ReviewExemptionClaimTask.find_by(application_form: exemption_application_form).completed!
      certification_case.accept_exemption_request(nil, exemption_application_form)
      reassign_compliance_read_model
    end

    it 'renders the green "eligible for an exemption" alert' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--success[role="region"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.approved.title'))
    end

    it 'renders the "Exemption details" heading and history with an EXEMPT badge' do
      render
      expect(rendered).to have_selector('h2', text: I18n.t('dashboard.member_compliance.exemption_details_heading'))
      expect(rendered).to have_selector('.member-dashboard-compliance__badge--exempt',
                                        text: I18n.t('dashboard.member_compliance.exemption_badges.exempt'))
    end

    it 'renders the approved exemption type label from the form' do
      render
      expect(rendered).to have_text(I18n.t("exemption_types.incarceration.title"))
    end

    it 'has a button to view the completed certification' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_approved.view_certification_button'))
    end

    it 'does not render a reporting section' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
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

      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 40, hours_by_category: {}, hours_by_source: { external: 40, activity: 0 },
        external_hourly_activity_ids: [], activity_ids: []
      })
      ReviewActivityReportTask.find_by(application_form: activity_report_application_form).completed!
      certification_case.deny_activity_report(nil, activity_report_application_form)
    end

    it 'renders a message that the activity report is denied' do
      render
      expect(rendered).to have_selector('p', text: I18n.t('dashboard.activity_report_denied.intro'))
    end

    it 'has a button to view the activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_denied.view_activity_report_button'))
    end

    it 'renders button to submit a new activity report' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.activity_report_denied.submit_new_activity_report_button'))
    end

    context "with reported activities (OSCER-642: denied activities must not render a table)" do
      let(:lookback) { certification.certification_requirements.continuous_lookback_period }

      before do
        create(:hourly_activity, activity_report_application_form_id: activity_report_application_form.id,
               name: "Denied job", category: "employment", hours: 30, month: lookback.start.to_date)
        reassign_compliance_read_model
      end

      it "does not render an activity table for the denied report, but keeps the view-report button" do
        render
        expect(rendered).not_to have_css(".member-dashboard-compliance__table--hours")
        expect(rendered).not_to have_css(".member-dashboard-compliance__table--income")
        expect(rendered).to have_selector("a", text: I18n.t("dashboard.activity_report_denied.view_activity_report_button"))
      end

      it "still renders the Activity line items section (OSCER-690 recommendation A) even though summary tables are skipped" do
        render
        expect(rendered).to have_selector("h2#member-compliance-line-items-heading",
                                          text: I18n.t("dashboard.member_compliance.activity_line_items.heading"))
        expect(rendered).to have_selector(".member-dashboard-compliance__line-items", text: "Denied job")
      end
    end

    context "when verification window ended" do
      before { certification_case.update_attribute!(:verification_window_end_date, 1.day.ago) }

      it 'does not render the button to submit a new activity report' do
        render
        expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.activity_report_denied.submit_new_activity_report_button'))
      end
    end

    context "when case closed" do
      before { certification_case.close! }

      it 'does not render the button to submit a new activity report' do
        render
        expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.activity_report_denied.submit_new_activity_report_button'))
      end
    end
  end

  context "with a denied exemption request" do
    let (:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

    before do
      assign(:exemption_application_form, exemption_application_form)
      assign(:certification_case, certification_case)

      ReviewExemptionClaimTask.find_by(application_form: exemption_application_form).completed!
      certification_case.deny_exemption_request(nil)
      reassign_compliance_read_model
    end

    it 'renders the red "you don\'t qualify" alert' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--error[role="alert"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.denied.title'))
    end

    it 'renders the "Exemption details" heading and history with a NOT EXEMPT badge' do
      render
      expect(rendered).to have_selector('h2', text: I18n.t('dashboard.member_compliance.exemption_details_heading'))
      expect(rendered).to have_selector('.member-dashboard-compliance__badge--not-exempt',
                                        text: I18n.t('dashboard.member_compliance.exemption_badges.not_exempt'))
    end

    it 'has a button to view the exemption' do
      render
      expect(rendered).to have_selector('a', text: I18n.t('dashboard.exemption_denied.view_exemption_button'))
    end

    context "when income summary is visible" do
      before do
        create(:determination,
               subject: certification,
               outcome: MemberStatus::NOT_COMPLIANT,
               decision_method: "automated",
               reasons: [ "income_reported_compliant" ],
               determination_data: {
                 "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
                 "satisfied_by" => Determination::SATISFIED_BY_BOTH
               })
        reassign_compliance_read_model
      end

      it 'renders the income-inclusive denied alert body' do
        render
        due_date = I18n.l(certification.certification_requirements.due_date, format: :long)
        target_income = ActiveSupport::NumberHelper.number_to_currency(
          IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY,
          precision: 0
        )
        expected = I18n.t(
          "dashboard.member_compliance.exemption_alerts.denied.body",
          target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
          target_income: target_income,
          due_date: due_date
        )

        expect(rendered).to have_text(expected)
      end
    end

    context "when income summary is hidden (hours-only path)" do
      before do
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "hours_reported_compliant" ],
               determination_data: { "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED })
        reassign_compliance_read_model
      end

      it 'renders the hours-only denied alert body with coverage month' do
        render
        due_date = I18n.l(certification.certification_requirements.due_date, format: :long)
        coverage_month = I18n.l(
          certification.certification_requirements.due_date.next_month.beginning_of_month,
          format: :month_name
        )
        expected = I18n.t(
          "dashboard.member_compliance.exemption_alerts.denied.body_hours",
          target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
          due_date: due_date,
          coverage_month: coverage_month
        )

        expect(rendered).to have_text(expected)
      end
    end

    it 'renders a button to start reporting activities' do
      render
      expect(rendered).to have_selector(
        'a',
        text: I18n.t('dashboard.member_compliance.reporting.start_reporting_activities_button')
      )
    end

    it 'renders the "Reported activities" heading and intro above the CTA' do
      render
      expect(rendered).to have_selector(
        'h2#member-compliance-reporting-heading',
        text: I18n.t('dashboard.member_compliance.reporting.heading')
      )
      expect(rendered).to have_selector('.member-dashboard-compliance__reporting-intro')
    end

    it 'renders button to resubmit next to the exemption details heading' do
      render
      button_text = I18n.t('dashboard.exemption_denied.submit_new_exemption_button')
      screener_path = exemption_screener_path(certification_case_id: certification_case.id)
      expect(rendered).to have_selector(
        '.member-dashboard-compliance__section-header #exemption-details-heading'
      )
      expect(rendered).to have_selector(
        ".member-dashboard-compliance__section-header-actions a.usa-button--outline[href='#{screener_path}']",
        text: button_text
      )
      expect(rendered).not_to have_selector(
        '.member-dashboard-compliance__exemption-action a',
        text: button_text
      )
    end

    it 'does not offer to retake the screener or render the get started callout after a caseworker denial' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.member_compliance.exemption_alerts.not_started.button'))
    end

    context "when verification window ended" do
      before { certification_case.update_attribute!(:verification_window_end_date, 1.day.ago) }

      it 'does not render button to resubmit' do
        render
        expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.exemption_denied.submit_new_exemption_button'))
      end
    end

    context "when case closed" do
      before { certification_case.close! }

      it 'does not render button to resubmit' do
        render
        expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.exemption_denied.submit_new_exemption_button'))
      end
    end

    context "with an in-progress activity report" do
      let(:activity_report_application_form) do
        create(:activity_report_application_form, certification_case_id: certification_case.id)
      end

      before { reassign_compliance_read_model }

      it 'renders the activity report continue button when a report is in progress' do
        render
        expect(rendered).to have_selector(
          'a',
          text: I18n.t('dashboard.member_compliance.reporting.continue_report_button')
        )
      end
    end
  end

  context "with a resubmitted exemption after a prior denial" do
    let(:exemption_application_form) do
      prior_form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      ReviewExemptionClaimTask.find_by(application_form: prior_form).completed!
      certification_case.deny_exemption_request(nil)
      create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
    end

    before do
      assign(:exemption_application_form, exemption_application_form)
      reassign_compliance_read_model
    end

    it 'renders the pending review alert instead of the denied alert' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--review')
      expect(rendered).not_to have_css('.member-dashboard-compliance__alert--error[role="alert"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.pending_review.title'))
    end

    it 'does not render the submit new exemption button' do
      render
      expect(rendered).not_to have_selector(
        'a',
        text: I18n.t('dashboard.exemption_denied.submit_new_exemption_button')
      )
    end
  end

  context "when the member is exempt via an automated determination" do
    before do
      create(:determination,
             subject: certification,
             outcome: "exempt",
             decision_method: "automated",
             reasons: [ "age_under_19_exempt" ])
      reassign_compliance_read_model
    end

    it 'renders the green "eligible for an exemption" alert and EXEMPT badge' do
      render
      expect(rendered).to have_css('.member-dashboard-compliance__alert--success[role="region"]')
      expect(rendered).to have_selector('h3', text: I18n.t('dashboard.member_compliance.exemption_alerts.approved.title'))
      expect(rendered).to have_selector('.member-dashboard-compliance__badge--exempt',
                                        text: I18n.t('dashboard.member_compliance.exemption_badges.exempt'))
    end

    it 'does not render a reporting section or get-started callout' do
      render
      expect(rendered).not_to have_selector('a', text: I18n.t('dashboard.new_certification.current_period.report_activities_button'))
      expect(rendered).not_to have_css('.member-dashboard-compliance__onboarding')
    end
  end

  context "with an in-progress activity report and reported activities (OSCER-642)" do
    let(:activity_report_application_form) do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
    end
    let(:lookback) { certification.certification_requirements.continuous_lookback_period }
    let(:hours_table) { ".member-dashboard-compliance__table--hours" }
    let(:income_table) { ".member-dashboard-compliance__table--income" }

    def create_external_hourly(hours: 30)
      create(:external_hourly_activity, member_id: certification.member_id, category: "employment",
             hours: hours, period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month)
    end

    def create_external_income(gross_income: 300)
      create(:external_income_activity, member_id: certification.member_id, category: "employment",
             gross_income: gross_income, period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month)
    end

    before do
      assign(:activity_report_application_form, activity_report_application_form)
    end


    context "when only hours have been reported" do
      before do
        create_external_hourly
        reassign_compliance_read_model
      end

      it "renders the hours table only, under the month-based activity report heading" do
        render
        month = I18n.l(certification.certification_requirements.certification_date, format: :month_year)
        expect(rendered).to have_selector("h3", text: "#{month} Activity Report")
        expect(rendered).to have_css(hours_table)
        expect(rendered).not_to have_css(income_table)
      end
    end

    context "when only income has been reported" do
      before do
        create_external_income
        reassign_compliance_read_model
      end

      it "renders the income table only" do
        render
        expect(rendered).to have_css(income_table)
        expect(rendered).not_to have_css(hours_table)
      end
    end

    context "when both hours and income have been reported" do
      before do
        create_external_hourly
        create_external_income
        reassign_compliance_read_model
      end

      it "renders both tables, hours first" do
        render
        expect(rendered).to have_css(hours_table)
        expect(rendered).to have_css(income_table)
        expect(rendered.index("member-dashboard-compliance__table--hours"))
          .to be < rendered.index("member-dashboard-compliance__table--income")
      end
    end

    context "when no activities have been reported yet" do
      it "renders the empty reporting copy and no tables" do
        render
        expect(rendered).to have_text(I18n.t("dashboard.member_compliance.reporting.no_activity_reported"))
        expect(rendered).not_to have_css(hours_table)
        expect(rendered).not_to have_css(income_table)
      end
    end


    it "renders continue and submit CTAs while the report is unsubmitted" do
      render
      expect(rendered).to have_selector("a", text: I18n.t("dashboard.member_compliance.reporting.continue_report_button"))
      expect(rendered).to have_link(
        I18n.t("dashboard.member_compliance.reporting.submit_button"),
        href: review_activity_report_application_form_path(activity_report_application_form)
      )
    end
  end

  context "with activity line items (OSCER-690)" do
    let(:lookback) { certification.certification_requirements.continuous_lookback_period }
    let(:line_items_section) { ".member-dashboard-compliance__line-items" }

    context "with a single in-progress form that has reported activities" do
      let(:activity_report_application_form) do
        form = create(:activity_report_application_form, certification_case_id: certification_case.id)
        create(:hourly_activity, activity_report_application_form_id: form.id, name: "Helping Hands",
               category: "employment", hours: 20, month: lookback.start.to_date)
        form
      end

      before do
        assign(:activity_report_application_form, activity_report_application_form)
        reassign_compliance_read_model
      end

      it "renders the line items heading and a table with the activity's organization and month" do
        render
        expect(rendered).to have_selector("h2#member-compliance-line-items-heading",
                                          text: I18n.t("dashboard.member_compliance.activity_line_items.heading"))
        expect(rendered).to have_selector("#{line_items_section} td", text: "Helping Hands")
        expect(rendered).to have_selector("#{line_items_section} td",
                                          text: I18n.l(lookback.start.to_date, format: :month_abbr_year))
      end

      it "does not render a per-form submitted-date subheading or status badge for a single form" do
        render
        expect(rendered).not_to have_selector("#{line_items_section} h3")
        expect(rendered).not_to have_selector("#{line_items_section} .usa-tag")
      end
    end

    context "with multiple forms on the case (older denied + newer submitted)" do
      # Built entirely in this before (not via let!) so the no-op event stub is in place before
      # any form is submitted: submitting must not spin up a pending review task that would block
      # a second form on the same case (mirrors certification_cases_spec). The older form's review
      # task records a per-form "denied" decision; the newer form is submitted. The shared outer
      # before assigns a nil activity report first; this reassigns the newer form afterward.
      let(:activity_report_application_form) { nil }

      before do
        allow(Strata::EventManager).to receive(:publish)

        denied_form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:hourly_activity, activity_report_application_form_id: denied_form.id, name: "Older Employer Inc",
               category: "employment", hours: 30, month: lookback.start.to_date)
        task = create(:review_activity_report_task, application_form: denied_form, case: certification_case)
        task.approval_status = :denied
        task.completed!

        submitted_form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:income_activity, activity_report_application_form_id: submitted_form.id, name: "Newer Employer Inc",
               category: "employment", income: 50_000, month: lookback.start.to_date)

        denied_form.update_column(:created_at, 2.days.ago)
        submitted_form.update_column(:created_at, 1.day.ago)

        assign(:activity_report_application_form, submitted_form)
        reassign_compliance_read_model
      end

      it "renders one table per form with both organization names" do
        render
        expect(rendered).to have_selector(line_items_section, text: "Older Employer Inc")
        expect(rendered).to have_selector(line_items_section, text: "Newer Employer Inc")
      end

      it "labels each form with a status badge (denied + submitted) so re-submissions are distinguishable" do
        render
        expect(rendered).to have_selector("#{line_items_section} .usa-tag",
                                          text: I18n.t("dashboard.member_compliance.activity_line_items.form_status.denied"))
        expect(rendered).to have_selector("#{line_items_section} .usa-tag",
                                          text: I18n.t("dashboard.member_compliance.activity_line_items.form_status.submitted"))
      end

      it "orders forms newest first (submitted above denied)" do
        render
        expect(rendered.index("Newer Employer Inc")).to be < rendered.index("Older Employer Inc")
      end

      it "omits the staff-only Doc AI confidence column even when Doc AI is enabled" do
        with_doc_ai_enabled do
          render
          expect(rendered).not_to have_text(I18n.t("activity_report_application_forms.staff_activity_report.confidence"))
        end
      end
    end
  end

  context "with a completed prior certification period" do
    before { assign_previous_completed_certification_period }

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
