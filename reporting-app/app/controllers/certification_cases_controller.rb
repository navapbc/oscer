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
    @activity_report = ActivityReportApplicationForm.find_by(certification_case_id: @case.id)
    @member_status = MemberStatusService.determine(@case)
    @tasks = @case.tasks.order(created_at: :desc)

    # Hours data for the "Hours reported" table
    @hours_summary = HoursComplianceDeterminationService.aggregate_hours_for_certification(@certification)
    @target_hours = HoursComplianceDeterminationService::TARGET_HOURS
    @external_hourly_activities = fetch_external_hourly_activities
    @hours_member_activities = HoursComplianceDeterminationService.member_hour_activities_for_certification(
      @certification,
      certification_case: @case
    )
    @external_income_activities = fetch_external_income_activities
    @member_income_activities = IncomeComplianceDeterminationService.member_income_activities_for_certification(
      @certification,
      certification_case: @case
    )
    member_income_rows = @member_income_activities.to_a
    @income_summary = IncomeComplianceDeterminationService.aggregate_income_for_certification(
      @certification,
      certification_case: @case,
      external_income_activities: @external_income_activities,
      member_income_activity_rows: member_income_rows
    )
    @target_income = IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
    if Features.doc_ai_enabled? && @activity_report
      activity_ids = @activity_report.activities.pluck(:id)
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
    [ ActivityReportApplicationForm, ExemptionApplicationForm ].map do |form_class|
      form_class.find_by_certification_case_id(@case.id)&.id
    end.compact
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
