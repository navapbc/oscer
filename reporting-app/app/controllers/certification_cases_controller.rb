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
end
