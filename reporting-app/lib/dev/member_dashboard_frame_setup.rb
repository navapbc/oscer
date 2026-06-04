# frozen_string_literal: true

module Dev
  # Local-only helper to put a member account into one of the OSCER-337 / #480
  # dashboard frames for manual QA at /dashboard.
  class MemberDashboardFrameSetup
    FRAMES = {
      "get_started" => "Frame 1 — Get started (exemption not started)",
      "exemption_draft" => "Frame 2 — Exemption draft in progress",
      "exemption_pending_review" => "Frame 3 — Exemption under review",
      "exemption_approved" => "Frame 4 — Exempt",
      "exemption_denied" => "Frame 5 — Not exempt, start reporting",
      "hours_only_reporting" => "Frame 6 — Hours-only reporting in progress (partial: 46 / 80 hrs)",
      "income_reporting" => "Frame 7 — Income reporting ($0 / $580)",
      "partial_income" => "Frame 8 — Partial income ($136 / $580)"
    }.freeze

    # Backward-compatible aliases (docs/specs sometimes use longer names).
    FRAME_ALIASES = {
      "exemption_denied_start_reporting" => "exemption_denied"
    }.freeze

    class << self
      def list_frames
        FRAMES.each { |key, label| puts "  #{key.ljust(24)} #{label}" }
      end

      def apply!(email:, frame:)
        new(email).apply!(frame)
      end
    end

    def initialize(email)
      @email = email
    end

    def apply!(frame)
      frame = normalize_frame(frame.to_s)
      raise ArgumentError, "Unknown frame #{frame.inspect}. Run rake dev:member_dashboard:frames" unless FRAMES.key?(frame)

      ensure_development!
      user, certification, certification_case = find_or_create_member_certification!
      @member_user = user
      reset_dashboard_state!(certification_case)
      reset_determinations!(certification)

      case frame
      when "get_started"
        ensure_income_determination!(certification)
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
        create_submitted_exemption!(certification_case)
        deny_exemption!(certification_case)
        ensure_income_determination!(certification)
      when "hours_only_reporting"
        create_submitted_exemption!(certification_case)
        deny_exemption!(certification_case)
        ensure_hours_determination!(certification)
        form = create_in_progress_activity_report!(certification, certification_case)
        seed_partial_hours_activities!(certification, form)
      when "income_reporting"
        create_submitted_exemption!(certification_case)
        deny_exemption!(certification_case)
        ensure_income_determination!(certification)
        create_in_progress_activity_report!(certification, certification_case)
      when "partial_income"
        create_submitted_exemption!(certification_case)
        deny_exemption!(certification_case)
        ensure_income_determination!(certification)
        form = create_in_progress_activity_report!(certification, certification_case)
        seed_partial_income_activities!(certification, form)
      end

      summarize!(user, certification, certification_case, frame)
    end

    private

    def ensure_development!
      return if Rails.env.development?

      raise "MemberDashboardFrameSetup is only available in development"
    end

    def normalize_frame(frame)
      FRAME_ALIASES.fetch(frame, frame)
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

      destroy_activity_report!(certification_case)
      destroy_exemption!(certification_case)
    end

    def reset_determinations!(certification)
      Determination.where(subject: certification).delete_all
    end

    def destroy_activity_report!(certification_case)
      form = activity_report_form_for(certification_case)
      return if form.blank?

      destroy_form!(form)
    end

    def destroy_exemption!(certification_case)
      form = exemption_form_for(certification_case)
      return if form.blank?

      destroy_form!(form)
    end

    def activity_report_form_for(certification_case)
      ActivityReportApplicationForm.unscoped
        .includes(:determinations, :activities)
        .find_by(certification_case_id: certification_case.id)
    end

    def exemption_form_for(certification_case)
      ExemptionApplicationForm.unscoped
        .with_attached_supporting_documents
        .includes(:determinations)
        .find_by(certification_case_id: certification_case.id)
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

    def deny_exemption!(certification_case)
      certification_case.update!(
        exemption_request_approval_status: "denied",
        exemption_request_approval_status_updated_at: Time.current
      )
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

    def create_in_progress_activity_report!(certification, certification_case)
      lookback = certification.certification_requirements.continuous_lookback_period
      month = lookback&.start&.to_date || Date.current.beginning_of_month

      FactoryBot.create(
        :activity_report_application_form,
        certification_case_id: certification_case.id,
        user_id: @member_user.id,
        reporting_periods: [ { "year" => month.year, "month" => month.month } ]
      )
    end

    def seed_partial_income_activities!(certification, activity_report_form)
      lookback_month = certification.certification_requirements.continuous_lookback_period.start.to_date

      create(:income_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Greater Boston Food Bank",
             category: "community_service",
             income: 5_000,
             month: lookback_month)
      create(:income_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Local Public library",
             category: "education",
             income: 5_000,
             month: lookback_month)
      create(:income_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Neighborhood Pantry",
             category: "community_service",
             income: 3_600,
             month: lookback_month)
    end

    def seed_partial_hours_activities!(certification, activity_report_form)
      lookback_month = certification.certification_requirements.continuous_lookback_period.start.to_date

      create(:work_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Greater Boston Food Bank",
             category: "community_service",
             hours: 20,
             month: lookback_month)
      create(:work_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Bunker Hill Community College",
             category: "education",
             hours: 15,
             month: lookback_month)
      create(:work_activity,
             activity_report_application_form_id: activity_report_form.id,
             name: "Boys & Girls Club of Eastern Massachusetts",
             category: "community_service",
             hours: 11,
             month: lookback_month)
    end

    def create(*args, **kwargs)
      FactoryBot.create(*args, **kwargs)
    end

    def summarize!(user, certification, certification_case, frame)
      exemption_form = ExemptionApplicationForm.find_by(certification_case_id: certification_case.id)
      activity_form = ActivityReportApplicationForm.find_by(certification_case_id: certification_case.id)
      member_status = MemberStatusService.determine(certification)
      compliance = MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case,
        activity_report_application_form: activity_form,
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
          Report status:         #{compliance.report_status_token}
          Exemption form:        #{exemption_form ? (exemption_form.submitted? ? "submitted" : "draft") : "none"}
          Activity report form:  #{activity_form ? (activity_form.submitted? ? "submitted" : "in-progress") : "none"}
          Total income:          #{compliance.show_income_summary ? number_to_currency(compliance.total_income, precision: 0) : "n/a"}

        Open http://localhost:3000/dashboard as #{@email} (hard refresh if styles look wrong).

        Switch frames:
          docker compose exec reporting-app bin/rake 'dev:member_dashboard:apply[#{@email},FRAME]'

      SUMMARY
    end

    def number_to_currency(amount, **)
      ActiveSupport::NumberHelper.number_to_currency(amount, **)
    end
  end
end
