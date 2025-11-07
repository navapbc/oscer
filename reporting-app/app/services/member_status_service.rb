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
      determine_many([ record ]).values.first
    end

    # Determines member statuses for multiple records in batch (O(1) queries)
    #
    # @param records [Array, ActiveRecord::Relation] Array or relation of Certification and/or CertificationCase records
    # @return [Hash] Hash keyed by [record.class.name, record.id] with MemberStatus values
    # @raise [ArgumentError] If records contain types other than Certification or CertificationCase
    def determine_many(records)
      records_array = records.is_a?(ActiveRecord::Relation) ? records.to_a : Array(records)
      return {} if records_array.empty?

      # Validate all records are correct type
      records_array.each do |record|
        raise ArgumentError, "Record must be a Certification or CertificationCase, got #{record.class}" unless valid_record_type?(record)
      end

      # Group by type
      certifications = records_array.select { |r| r.is_a?(Certification) }
      cases = records_array.select { |r| r.is_a?(CertificationCase) }

      # Collect all certification IDs we need
      cert_ids = certifications.map(&:id) + cases.map(&:certification_id).compact
      cert_ids = cert_ids.uniq

      # Bulk load cross-references
      cases_by_cert_id = CertificationCase.where(certification_id: cert_ids).index_by(&:certification_id)
      certs_by_id = Certification.where(id: cert_ids).index_by(&:id)

      # Bulk load latest determinations
      latest_dets = Determination.for_certifications(cert_ids).latest_per_subject.index_by(&:subject_id)

      # Memoize human-readable translations
      @translation_cache = {}

      # Build results
      results = {}
      records_array.each do |record|
        cert, case_record = build_pair(record, certs_by_id, cases_by_cert_id)
        status = compute_status(cert, case_record, latest_dets)
        results[[ record.class.name, record.id ]] = status
      end

      results
    end

    private

    def valid_record_type?(record)
      record.is_a?(Certification) || record.is_a?(CertificationCase)
    end

    def build_pair(record, certs_by_id, cases_by_cert_id)
      case record
      when Certification
        certification = record
        certification_case = cases_by_cert_id[certification.id]
      when CertificationCase
        certification_case = record
        certification = certs_by_id[record.certification_id]
      end

      [ certification, certification_case ]
    end

    def compute_status(certification, certification_case, latest_dets)
      determination = latest_dets[certification&.id]

      if determination.present?
        status_from_determination(determination)
      else
        status_from_case_step(certification_case)
      end
    end

    def status_from_determination(determination)
      MemberStatus.new(
        status: determination.outcome,
        determination_method: determination.decision_method,
        reason_codes: determination.reasons,
        human_readable_reason_codes: human_readable_reason_codes(determination.reasons)
      )
    end

    def status_from_case_step(certification_case)
      return awaiting_report_status if certification_case.blank?

      case certification_case.business_process_current_step
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

    def human_readable_reason_codes(reasons)
      @translation_cache ||= {}
      reasons.map do |reason|
        @translation_cache[reason] ||= I18n.t("services.member_status_service.reason_codes.#{reason}", default: reason)
      end
    end
  end
end
