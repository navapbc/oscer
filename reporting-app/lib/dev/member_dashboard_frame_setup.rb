# frozen_string_literal: true

module Dev
  # Local-only helper to put a member account into OSCER-337 member dashboard frames
  # (#640 exemption outcomes, #641 draft, #642 reporting activity tables) for manual QA
  # at /dashboard. Progress cards land with #643.
  class MemberDashboardFrameSetup
    FRAMES = {
      "exemption_draft" => "Frame 2 — Exemption draft in progress",
      "exemption_pending_review" => "Frame 3 — Exemption under review",
      "exemption_approved" => "Frame 4 — Exempt",
      "exemption_denied" => "Frame 5 — Not exempt",
      "reporting_hours" => "Frame 6 — Reporting in progress (hours table)",
      "reporting_income" => "Frame 7 — Reporting in progress (income table)",
      "reporting_both" => "Frame 8 — Reporting in progress (hours + income tables)",
      "reporting_submitted" => "Frame 9 — Activity report submitted (tables + under review)",
      "reporting_multiple" => "Frame 10 — Multiple activity reports (older denied + newer submitted line items)"
    }.freeze

    class << self
      def list_frames
        FRAMES.each { |key, label| puts "  #{key.ljust(28)} #{label}" }
      end

      def apply!(email:, frame:)
        new(email).apply!(frame)
      end
    end

    def initialize(email)
      @email = email
    end

    def apply!(frame)
      frame = frame.to_s
      raise ArgumentError, "Unknown frame #{frame.inspect}. Run rake dev:member_dashboard:frames" unless FRAMES.key?(frame)

      ensure_development!
      user, certification, certification_case = find_or_create_member_certification!
      @member_user = user
      reset_dashboard_state!(certification_case)
      reset_determinations!(certification)
      reset_external_activities!(certification)

      case frame
      when "exemption_draft"
        ensure_income_determination!(certification)
        create_draft_exemption!(certification_case)
      when "exemption_pending_review"
        ensure_income_determination!(certification)
        create_submitted_exemption!(certification_case)
      when "exemption_approved"
        form = create_submitted_exemption!(certification_case)
        approve_exemption!(certification, certification_case, form)
      when "exemption_denied"
        form = create_submitted_exemption!(certification_case)
        deny_exemption!(certification_case, form)
        ensure_income_determination!(certification)
      when "reporting_hours"
        ensure_hours_determination!(certification)
        create_in_progress_activity_report!(certification_case)
        create_external_hourly!(certification)
      when "reporting_income"
        ensure_income_determination!(certification)
        create_in_progress_activity_report!(certification_case)
        create_external_income!(certification)
      when "reporting_both"
        ensure_income_determination!(certification)
        create_in_progress_activity_report!(certification_case)
        create_external_hourly!(certification)
        create_external_income!(certification)
      when "reporting_submitted"
        ensure_income_determination!(certification)
        create_submitted_activity_report!(certification_case)
        create_external_income!(certification)
      when "reporting_multiple"
        ensure_income_determination!(certification)
        denied_form = create_submitted_activity_report_with_activities!(certification_case)
        deny_activity_report_form!(certification_case, denied_form)
        create_submitted_activity_report_with_activities!(certification_case)
        create_external_income!(certification)
      end

      summarize!(user, certification, certification_case, frame)
    end

    private

    def ensure_development!
      return if Rails.env.development?

      raise "MemberDashboardFrameSetup is only available in development"
    end

    def find_or_create_member_certification!
      user = User.find_by(email: @email)
      raise "No User with email #{@email.inspect}. Sign up via /users/sign_up or create the account first." if user.blank?

      certification = Certification.find_by_member_email(@email).order(created_at: :desc).first
      if certification.blank?
        certification = FactoryBot.create(
          :certification,
          :connected_to_email,
          email: @email,
          member_data: FactoryBot.build(:certification_member_data, :with_full_name)
        )
      end

      certification_case = MemberDashboardComplianceService.case_for_certification(certification)
      raise "No certification case for #{@email}" if certification_case.blank?

      [ user, certification, certification_case ]
    end

    def reset_dashboard_state!(certification_case)
      certification_case.update!(
        exemption_request_approval_status: nil,
        exemption_request_approval_status_updated_at: nil,
        activity_report_approval_status: nil,
        activity_report_approval_status_updated_at: nil
      )

      destroy_activity_reports!(certification_case)
      destroy_exemption!(certification_case)
    end

    def reset_determinations!(certification)
      Determination.where(subject: certification).delete_all
    end

    def reset_external_activities!(certification)
      ExternalHourlyActivity.for_member(certification.member_id).delete_all
      ExternalIncomeActivity.for_member(certification.member_id).delete_all
    end

    def destroy_activity_reports!(certification_case)
      ActivityReportApplicationForm.unscoped
        .includes(:determinations, :activities)
        .where(certification_case_id: certification_case.id)
        .find_each { |form| destroy_form!(form) }
    end

    def destroy_exemption!(certification_case)
      form = ExemptionApplicationForm.unscoped
        .with_attached_supporting_documents
        .includes(:determinations)
        .find_by(certification_case_id: certification_case.id)
      return if form.blank?

      destroy_form!(form)
    end

    def destroy_form!(form)
      InformationRequest.where(application_form_id: form.id, application_form_type: form.class.name).delete_all
      OscerTask.where(application_form_id: form.id).delete_all
      form.strict_loading!(false)
      form.destroy!
    end

    def create_draft_exemption!(certification_case)
      ExemptionApplicationForm.create!(
        certification_case_id: certification_case.id,
        exemption_type: "caregiver_child",
        user_id: @member_user.id
      )
    end

    def create_submitted_exemption!(certification_case)
      FactoryBot.create(
        :exemption_application_form,
        :with_submitted_status,
        certification_case_id: certification_case.id,
        exemption_type: "caregiver_child",
        user_id: @member_user.id
      )
    end

    def approve_exemption!(certification, certification_case, exemption_form)
      certification_case.update!(
        exemption_request_approval_status: "approved",
        exemption_request_approval_status_updated_at: Time.current
      )

      certification.record_determination!(
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING.fetch(:exemption_request_compliant) ],
        outcome: :exempt,
        determination_data: { "exemption_type" => exemption_form.exemption_type },
        determined_at: certification.certification_requirements.certification_date
      )
    end

    def deny_exemption!(certification_case, exemption_form)
      task = ReviewExemptionClaimTask.find_by(application_form: exemption_form) ||
             FactoryBot.create(:review_exemption_claim_task, application_form: exemption_form, case: certification_case)
      task.completed!
      certification_case.deny_exemption_request(nil)
    end

    def ensure_income_determination!(certification)
      certification.record_determination!(
        decision_method: :automated,
        reasons: [ "income_reported_compliant" ],
        outcome: MemberStatus::NOT_COMPLIANT,
        determination_data: {
          "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
          "satisfied_by" => Determination::SATISFIED_BY_BOTH
        },
        determined_at: certification.certification_requirements.certification_date
      )
    end

    def ensure_hours_determination!(certification)
      certification.record_determination!(
        decision_method: :automated,
        reasons: [ "hours_reported_compliant" ],
        outcome: MemberStatus::NOT_COMPLIANT,
        determination_data: { "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED },
        determined_at: certification.certification_requirements.certification_date
      )
    end

    def create_in_progress_activity_report!(certification_case)
      FactoryBot.create(:activity_report_application_form, certification_case_id: certification_case.id)
    end

    def create_submitted_activity_report!(certification_case)
      FactoryBot.create(:activity_report_application_form, :with_submitted_status,
                        certification_case_id: certification_case.id)
    end

    # Creates a submitted activity report with member-entered line items (an hourly + an income
    # activity) so the OSCER-690 line-item tables have rows to render.
    def create_submitted_activity_report_with_activities!(certification_case)
      form = FactoryBot.create(:activity_report_application_form, certification_case_id: certification_case.id)
      add_line_item_activities!(form)
      form.submit_application
      form
    end

    def add_line_item_activities!(form)
      FactoryBot.create(:hourly_activity, activity_report_application_form_id: form.id,
                        name: "Community Service Org", category: "employment", hours: 45)
      FactoryBot.create(:income_activity, activity_report_application_form_id: form.id,
                        name: "Acme Employer", category: "employment", income: 120_000)
    end

    # Marks a submitted activity report as denied via its review task (per-form decision read by
    # +activity_report_display_status+), mirroring how +deny_exemption!+ completes the exemption task.
    def deny_activity_report_form!(certification_case, form)
      task = ReviewActivityReportTask.find_by(application_form: form) ||
             FactoryBot.create(:review_activity_report_task, application_form: form, case: certification_case)
      task.update!(approval_status: :denied)
      task.completed!
    end

    def create_external_hourly!(certification)
      lookback = certification.certification_requirements.continuous_lookback_period
      FactoryBot.create(:external_hourly_activity,
                        member_id: certification.member_id,
                        category: "employment",
                        hours: 40,
                        period_start: lookback.start.to_date,
                        period_end: lookback.start.to_date.end_of_month)
    end

    def create_external_income!(certification)
      lookback = certification.certification_requirements.continuous_lookback_period
      FactoryBot.create(:external_income_activity,
                        member_id: certification.member_id,
                        category: "employment",
                        gross_income: 300,
                        period_start: lookback.start.to_date,
                        period_end: lookback.start.to_date.end_of_month)
    end

    def summarize!(user, certification, certification_case, frame)
      exemption_form = ExemptionApplicationForm.find_by(certification_case_id: certification_case.id)
      member_status = MemberStatusService.determine(certification)
      compliance = MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case,
        activity_report_application_form: nil,
        exemption_application_form: exemption_form,
        member_status: member_status
      )

      puts <<~SUMMARY

        Member dashboard frame applied for #{@email}

          Frame:                 #{frame} — #{FRAMES.fetch(frame)}
          User id:               #{user.id}
          Certification:         #{certification.id}
          Certification case:    #{certification_case.id}
          Exemption flow:        #{compliance.exemption_flow_state}
          Show income summary:   #{compliance.show_income_summary}
          Exemption form:        #{exemption_form ? (exemption_form.submitted? ? "submitted" : "draft") : "none"}

        Open http://localhost:3000/dashboard as #{@email} (hard refresh if styles look wrong).

        Switch frames:
          docker compose exec reporting-app bin/rake 'dev:member_dashboard:apply[#{@email},FRAME]'

      SUMMARY
    end
  end
end
