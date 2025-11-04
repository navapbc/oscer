# frozen_string_literal: true

# Service for determining a member's certification status.
#
# The service checks for Determinations first (automated or manual decisions).
# If no Determination exists, it falls back to examining the CertificationCase
# approval statuses and related application forms to derive the current status.
#
# @example Determine status from a Certification
#   certification = Certification.find(id)
#   status = MemberStatusService.determine(certification)
#   status.status # => "compliant"
#
# @example Determine status from a CertificationCase
#   case = CertificationCase.find(id)
#   status = MemberStatusService.determine(case)
#   status.status # => "pending_review"
class MemberStatusService
  class << self
    # Determines the member's certification status
    #
    # @param record [Certification, CertificationCase] The record to determine status for
    # @return [MemberStatus] The member's current status with optional determination details
    # @raise [ArgumentError] If record is neither Certification nor CertificationCase
    def determine(record)
      certification, certification_case = normalize_input(record)

      determination = latest_determination_for(certification)

      if determination.present?
        status_from_determination(determination)
      else
        status_from_case_and_forms(certification_case)
      end
    end

    private

    def normalize_input(record)
      case record
      when Certification
        certification = record
        certification_case = CertificationCase.find_by(certification_id: certification.id)
      when CertificationCase
        certification_case = record
        certification = Certification.find_by(id: certification_case.certification_id)
      else
        raise ArgumentError, "Record must be a Certification or CertificationCase, got #{record.class}"
      end

      [ certification, certification_case ]
    end

    def latest_determination_for(certification)
      return nil if certification.blank?

      Determination.for_subject(certification).order(created_at: :desc).first # TODO: make this scope in SDK
    end

    def status_from_determination(determination)
      MemberStatus.new(
        status: determination.outcome,
        determination_method: determination.decision_method,
        reason_codes: determination.reasons
      )
    end

    def status_from_case_and_forms(certification_case)
      return awaiting_report_status if certification_case.blank?

      activity_report_form = ActivityReportApplicationForm.find_by_certification_case_id(certification_case.id)
      exemption_form = ExemptionApplicationForm.find_by_certification_case_id(certification_case.id)

      # Determine status based on application form submission and approval states
      if are_forms_incomplete?(activity_report_form, exemption_form)
        awaiting_report_status
      elsif is_activity_report_pending_review?(activity_report_form, certification_case)
        pending_review_status
      elsif is_exemption_pending_review?(exemption_form, certification_case)
        pending_review_status
      elsif is_activity_report_approved?(activity_report_form, certification_case)
        compliant_status
      elsif is_activity_report_denied?(activity_report_form, certification_case)
        not_compliant_status
      elsif is_exemption_approved?(exemption_form, certification_case)
        exempt_status
      elsif is_exemption_denied?(exemption_form, certification_case)
        not_compliant_status
      else
        awaiting_report_status
      end
    end

    def are_forms_incomplete?(activity_report_form, exemption_form)
      !activity_report_form&.submitted? && !exemption_form&.submitted?
    end

    def is_activity_report_pending_review?(activity_report_form, certification_case)
      activity_report_form&.submitted? && certification_case.activity_report_approval_status.nil?
    end

    def is_exemption_pending_review?(exemption_form, certification_case)
      exemption_form&.submitted? && certification_case.exemption_request_approval_status.nil?
    end

    def is_activity_report_approved?(activity_report_form, certification_case)
      activity_report_form&.submitted? && certification_case.activity_report_approval_status == "approved"
    end

    def is_activity_report_denied?(activity_report_form, certification_case)
      activity_report_form&.submitted? && certification_case.activity_report_approval_status == "denied"
    end

    def is_exemption_approved?(exemption_form, certification_case)
      exemption_form&.submitted? && certification_case.exemption_request_approval_status == "approved"
    end

    def is_exemption_denied?(exemption_form, certification_case)
      exemption_form&.submitted? && certification_case.exemption_request_approval_status == "denied"
    end

    def awaiting_report_status
      MemberStatus.new(status: "awaiting_report")
    end

    def pending_review_status
      MemberStatus.new(status: "pending_review")
    end

    def compliant_status
      MemberStatus.new(status: "compliant")
    end

    def not_compliant_status
      MemberStatus.new(status: "not_compliant")
    end

    def exempt_status
      MemberStatus.new(status: "exempt")
    end
  end
end
