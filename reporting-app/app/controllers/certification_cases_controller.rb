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
    @ex_parte_activities = fetch_ex_parte_activities
    @member_activities = fetch_member_activities
    @income_rows = fetch_incomes
    @member_income_activities = IncomeComplianceDeterminationService.member_income_activities_for_certification(
      @certification,
      certification_case: @case
    )
    @income_summary = IncomeComplianceDeterminationService.aggregate_income_for_certification(
      @certification,
      certification_case: @case
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

  def fetch_ex_parte_activities
    lookback_period = @certification.certification_requirements.continuous_lookback_period
    ExParteActivity.for_member(@certification.member_id).within_period(lookback_period)
  end

  def fetch_incomes
    lookback_period = @certification.certification_requirements.continuous_lookback_period
    Income.for_member(@certification.member_id)
      .within_period(lookback_period)
      .order(:period_start, :reported_at)
  end

  def fetch_member_activities
    # Only include activities from approved activity reports to match the totals calculation
    return [] unless @activity_report

    @activity_report.activities.where.not(hours: nil)
  end
end
