# frozen_string_literal: true

# Service for creating and validating ExternalActivity entries from API and batch intake.
# Supersedes ExternalHourlyActivityService and ExternalIncomeActivityService: one submission may
# report hours, gross income, or both, and is split into one entry per calendar month it touches.
#
# After a successful save, optional compliance recalculation (+recalculate_compliance+, default
# +true+) records exactly one determination for the member's open case — hours first, falling
# through to income only when hours fall short.
#
# That path is dormant: the only caller, +Certifications::CreationService+, passes
# +recalculate_compliance: false+ because the case does not exist yet at intake. Wiring up a
# caller that takes the default would start closing cases on a compliant outcome — note that
# +CertificationCase#record_hours_compliance+ has no +close_on_compliant+ opt-out the way
# +record_income_compliance+ does.
class ExternalActivityService
  include Strata::VirtualActor

  AUDIT_ACTION_CREATE = "external_activity.create"

  class << self
    include ActivityAggregator
    include OriginHash

    # Create one entry per calendar month the period touches.
    # A submission already on file is logged and skipped, leaving the caller's other work intact.
    # @param identity [Array] values beyond the name identifying whose figures these are (household
    #   income passes the member's tax ID and date of birth), folded into the fingerprint.
    # @return [Array<ExternalActivity>] the entries created, empty for a duplicate
    # @raise [ActiveRecord::RecordInvalid] on validation failure
    def create_entries(member_id:, category:, period_start:, period_end:, source_type:,
                       hours: nil, gross_income: nil, source_id: nil, reported_at: Time.current,
                       metadata: {}, name: nil, employer: nil, identity: [],
                       recalculate_compliance: true)
      origin_hash = origin_hash_for(member_id, category, hours, gross_income,
                                    period_start, period_end, name, *identity)

      if duplicate_entry?(origin_hash)
        log_duplicate_submission(origin_hash, member_id:, category:, period_start:, period_end:)
        return []
      end

      entries = month_entries(hours:, gross_income:, period_start:, period_end:)
        .map do |current_period_start, current_period_end, values|
          create_entry(member_id:, category:,
                       hours: values[:hours], gross_income: values[:gross_income],
                       period_start: current_period_start, period_end: current_period_end,
                       source_type:, source_id:, reported_at:, metadata:, name:, employer:,
                       origin_hash:, recalculate_compliance: false)
        end

      maybe_recalculate_compliance(member_id, hours:, gross_income:) if recalculate_compliance
      entries
    end

    # Duplicate detection belongs to +create_entries+.
    # @param recalculate_compliance [Boolean] when +true+ (default), after save record one
    #   automated determination for the open case (may +close!+ when compliant);
    #   +Certifications::CreationService+ passes +false+.
    # @return [ExternalActivity] on success
    # @raise [ActiveRecord::RecordInvalid] on validation failure
    def create_entry(member_id:, category:, period_start:, period_end:, source_type:,
                     hours: nil, gross_income: nil, source_id: nil, reported_at: Time.current,
                     metadata: {}, name: nil, employer: nil, origin_hash: nil,
                     recalculate_compliance: true)
      entry = ExternalActivity.new

      Strata::AuditLog.record do |log|
        entry.update!(
          member_id: member_id,
          category: category,
          hours: hours,
          gross_income: gross_income,
          period_start: period_start,
          period_end: period_end,
          source_type: source_type,
          source_id: source_id,
          reported_at: reported_at,
          name: name,
          origin_hash: origin_hash,
          metadata: (metadata || {}).merge(employer.present? ? { "employer" => employer } : {})
        )

        log.add_line(
          actor: self,
          action: AUDIT_ACTION_CREATE,
          subject: entry,
          data: entry.attributes
        )
      end

      if recalculate_compliance
        maybe_recalculate_compliance(entry.member_id, hours: entry.hours, gross_income: entry.gross_income)
      end

      entry
    end

    # Entries carrying no fingerprint (rows written before this column existed) are
    # not duplicates of anything.
    # @return [Boolean]
    def duplicate_entry?(origin_hash)
      return false if origin_hash.blank?

      ExternalActivity.exists?(origin_hash: origin_hash)
    end

    private

    # Hours present means both values apportion by days, so the two halves of one activity divide
    # along the same month boundaries. An income-only submission keeps the income rule: evenly
    # across whole calendar months, by days otherwise.
    def month_entries(hours:, gross_income:, period_start:, period_end:)
      if hours.present?
        return apportioned_multi_values_map(period_start, period_end, weight: :daily,
                                            hours:, gross_income:)
      end

      weight = whole_months?(period_start, period_end) ? :monthly : :daily
      apportioned_multi_values_map(period_start, period_end, weight:, gross_income:)
    end

    def whole_months?(period_start, period_end)
      period_start&.beginning_of_month == period_start && period_end&.end_of_month == period_end
    end

    # The open certification is resolved once: +open_certification_id_for_member+ filters on open
    # cases and recording a compliant outcome +close!+s the case, so a per-track lookup would let
    # the first compliant close silently skip the second track.
    def maybe_recalculate_compliance(member_id, hours:, gross_income:)
      certification_id = CertificationCase.open_certification_id_for_member(member_id)
      return if certification_id.blank?

      certification = Certification.find(certification_id)
      kase = certification_case_for_certification(certification)
      raise ActiveRecord::RecordNotFound, "Couldn't find CertificationCase for Certification #{certification_id}" unless kase

      record_one_determination(kase, certification, hours:, gross_income:)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn(
        "ExternalActivityService: skipped compliance recalculation " \
        "(case or certification missing) for member_id=#{member_id}"
      )
    end

    # Hours take precedence: income is consulted only when hours do not already satisfy the
    # requirement, so one save records one determination even for a row carrying both.
    #
    # The determination services' +.calculate+ methods aggregate *and* record, so calling both
    # would write two rows. The pieces they build on are public, so the branch is decided here and
    # only the winning track is recorded.
    #
    # Judged on monthly hours alone, matching +HoursComplianceDeterminationService#calculate+:
    # the education-enrollment track is deliberately not consulted here.
    def record_one_determination(kase, certification, hours:, gross_income:)
      application_form = ActivityReportApplicationForm.find_by(certification_case_id: kase.id)

      if hours.present?
        hours_data = HoursComplianceDeterminationService
          .aggregate_hours_for_certification(certification, application_form:)
        hours_compliant = HoursComplianceDeterminationService
          .compliant_for_monthly_hours?(hours_data[:hours_by_month])

        if hours_compliant || gross_income.blank?
          return kase.record_hours_compliance(hours_compliant ? :compliant : :not_compliant, hours_data)
        end
      end

      income_data = IncomeComplianceDeterminationService
        .aggregate_income_for_certification(certification, application_form:)
      income_compliant = IncomeComplianceDeterminationService
        .compliant_for_monthly_income?(income_data[:income_by_month])

      kase.record_income_compliance(income_compliant ? :compliant : :not_compliant, income_data)
    end
  end
end
