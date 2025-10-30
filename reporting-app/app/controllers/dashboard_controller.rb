# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_certifications
  before_action :set_certification_case, if: -> { @certification.present? }
  before_action :set_exemption_application_form, if: -> { @certification_case.present? }
  before_action :set_activity_report_application_form, if: -> { @certification_case.present? }
  before_action :set_information_requests, if: -> { @exemption_application_form.present? || @activity_report_application_form.present? }


  # TODO: figure out authz
  skip_after_action :verify_policy_scoped

  def index
  end

  private

  def set_certifications
    @all_certifications = Certification.find_by_member_email(current_user.email).order(created_at: :desc).all
    @certification = @all_certifications.first
  end

  def set_certification_case
    @certification_case = CertificationCase.find_by(certification_id: @certification&.id)
  end

  def set_exemption_application_form
    @exemption_application_form = ExemptionApplicationForm.find_by_certification_case_id(@certification_case&.id)
  end

  def set_activity_report_application_form
    @activity_report_application_form = ActivityReportApplicationForm.find_by_certification_case_id(@certification_case&.id)
  end

  def set_information_requests
    # TODO: The UI does not allow for multiple forms to be submitted, but the data model allows for it.
    # There should only be one information request possible for all application forms.
    @information_requests = InformationRequest.for_application_forms([ @exemption_application_form&.id, @activity_report_application_form&.id ].compact)
    @information_request = @information_requests.select { |request| request.member_comment.blank? && request.supporting_documents.empty? }.first
  end
end
