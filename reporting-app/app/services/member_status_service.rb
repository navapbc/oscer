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
      return {} if records.empty?

      # Validate all records are correct type
      records.each do |record|
        raise ArgumentError, "Record must be a Certification or CertificationCase, got #{record.class}" unless valid_record_type?(record)
      end

      # Group by type
      certifications = records.select { |r| r.is_a?(Certification) }
      cases = records.select { |r| r.is_a?(CertificationCase) }

      # Extract already-hydrated certifications from cases
      hydrated_certs = cases.map(&:certification).compact

      # Collect all certification IDs we need
      cert_ids = certifications.map(&:id) | cases.map(&:certification_id).compact

      # Bulk load all related data, reusing already-loaded records
      data = bulk_load_data(
        cert_ids,
        already_loaded_certs: certifications + hydrated_certs,
        already_loaded_cases: cases
      )

      # Memoize human-readable translations
      @translation_cache = {}

      # Build results
      results = {}
      records.each do |record|
        cert, case_record = build_pair(record, data[:certs_by_id], data[:cases_by_cert_id])
        status = compute_status(cert, case_record, data[:determinations])
        results[[ record.class.name, record.id ]] = status
      end

      results
    end

    private

    # Bulk loads all related data needed for status determination in a single operation
    #
    # @param cert_ids [Array<String>] Array of certification IDs to load data for
    # @param already_loaded_certs [Array<Certification>] Certifications already in memory to reuse
    # @param already_loaded_cases [Array<CertificationCase>] Cases already in memory to reuse
    # @return [Hash] Hash with keys :cases_by_cert_id, :certs_by_id, :determinations
    def bulk_load_data(cert_ids, already_loaded_certs: [], already_loaded_cases: [])
      # Build index of already-loaded certifications
      certs_by_id = already_loaded_certs.index_by(&:id)

      # Only load certifications we don't already have
      missing_cert_ids = cert_ids - certs_by_id.keys
      if missing_cert_ids.any?
        certs_by_id.merge!(Certification.where(id: missing_cert_ids).index_by(&:id))
      end

      # Build index of already-loaded cases
      cases_by_cert_id = already_loaded_cases.index_by(&:certification_id)

      # Only load cases we don't already have
      missing_case_cert_ids = cert_ids - cases_by_cert_id.keys
      if missing_case_cert_ids.any?
        cases_by_cert_id.merge!(CertificationCase.where(certification_id: missing_case_cert_ids).index_by(&:certification_id))
      end

      {
        cases_by_cert_id: cases_by_cert_id,
        certs_by_id: certs_by_id,
        determinations: Determination.for_certifications(cert_ids).latest_per_subject.index_by(&:subject_id)
      }
    end

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
      reasons.map do |reason|
        @translation_cache[reason] ||= I18n.t("services.member_status_service.reason_codes.#{reason}", default: reason)
      end
    end
  end
end
