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
        status_from_case_step(certification_case)
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
        reason_codes: determination.reasons,
        human_readable_reason_codes: determination.reasons.map { |reason| human_readable_reason_codes(reason) }
      )
    end

    def status_from_case_step(certification_case)
      return awaiting_report_status if certification_case.blank?

      case certification_case.business_process_instance.current_step
      when CertificationBusinessProcess::REPORT_ACTIVITIES_STEP
        awaiting_report_status
      when CertificationBusinessProcess::REVIEW_ACTIVITY_REPORT_STEP, CertificationBusinessProcess::REVIEW_EXEMPTION_CLAIM_STEP
        pending_review_status
      when CertificationBusinessProcess::END_STEP
        not_compliant_status
      else
        awaiting_report_status
      end
    end

    def awaiting_report_status
      MemberStatus.new(status: MemberStatus::AWAITING_REPORT)
    end

    def pending_review_status
      MemberStatus.new(status: MemberStatus::PENDING_REVIEW)
    end

    def not_compliant_status
      MemberStatus.new(status: MemberStatus::NOT_COMPLIANT)
    end

    def human_readable_reason_codes(reason)
      I18n.t("services.member_status_service.reason_codes.#{reason}", default: reason)
    end
  end
end
