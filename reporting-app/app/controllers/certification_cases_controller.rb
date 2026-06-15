# frozen_string_literal: true

class CertificationCasesController < StaffController
  helper Strata::DateHelper

  before_action :set_case, only: %i[ show tasks documents notes ]
  before_action :set_certification, only: %i[ show tasks documents notes ]

  def index
    @cases = policy_scope(CertificationCase).open
    certification_service.hydrate_cases_with_certifications!(@cases)
  end

  def closed
    @cases = policy_scope(CertificationCase).closed
    certification_service.hydrate_cases_with_certifications!(@cases)
    render :index
  end

  def show
    @information_requests = InformationRequest.for_application_forms(application_form_ids)
    @activity_reports = ActivityReportApplicationForm.where(certification_case_id: @case.id).order(created_at: :desc)
    # Drives the case-level compliance summary and the external-data section; the most recent
    # form preserves single-form behavior (where there is exactly one, it is that one).
    @activity_report = @activity_reports.first
    @member_status = MemberStatusService.determine(@case)
    @tasks = @case.tasks.order(created_at: :desc)

    # Hours data for the "Hours reported" table
    @target_hours = HoursComplianceDeterminationService::TARGET_HOURS
    @external_hourly_activities = fetch_external_hourly_activities
    @member_hour_activities = HoursComplianceDeterminationService.member_hour_activities_for_certification(
      @certification,
      application_form: @activity_report
    )
    member_hour_rows = @member_hour_activities.to_a
    @hours_summary = HoursComplianceDeterminationService.aggregate_hours_for_certification(
      @certification,
      application_form: @activity_report,
      external_hourly_activities: @external_hourly_activities,
      member_hour_activity_rows: member_hour_rows
    )
    @external_income_activities = fetch_external_income_activities
    @member_income_activities = IncomeComplianceDeterminationService.member_income_activities_for_certification(
      @certification,
      application_form: @activity_report
    )
    member_income_rows = @member_income_activities.to_a
    @income_summary = IncomeComplianceDeterminationService.aggregate_income_for_certification(
      @certification,
      application_form: @activity_report,
      external_income_activities: @external_income_activities,
      member_income_activity_rows: member_income_rows
    )
    @target_income = IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
    @hours_has_data = @external_hourly_activities.any? || @member_hour_activities.any?
    @income_has_data = @external_income_activities.any? || @member_income_activities.any?
    if Features.doc_ai_enabled? && @activity_reports.any?
      activity_ids = @activity_reports.flat_map { |form| form.activities.pluck(:id) }
      @confidence_by_activity = DocAiConfidenceService.new.confidence_by_activity_id(activity_ids)
    end
  end

  private

  def set_case
    @case = authorize CertificationCase.find(params[:id])
  end

  def set_certification
    @certification = Certification.find(@case.certification_id)
    @case.certification = @certification
    @member = Member.from_certification(@certification)
  end

  def certification_service
    CertificationService.new
  end

  def application_form_ids
    [ ActivityReportApplicationForm, ExemptionApplicationForm ].flat_map do |form_class|
      form_class.where(certification_case_id: @case.id).pluck(:id)
    end
  end

  def fetch_external_hourly_activities
    lookback_period = @certification.certification_requirements.continuous_lookback_period
    ExternalHourlyActivity.for_member(@certification.member_id).within_period(lookback_period)
  end

  def fetch_external_income_activities
    lookback_period = @certification.certification_requirements.continuous_lookback_period
    ExternalIncomeActivity.for_member(@certification.member_id)
      .within_period(lookback_period)
      .order(:period_start, :reported_at)
  end
end
