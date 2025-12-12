# frozen_string_literal: true

class HoursComplianceDeterminationService
  TARGET_HOURS = ENV.fetch("CE_TARGET_MONTHLY_HOURS", 80).to_i

  class << self
    # PRIMARY: Called by CertificationBusinessProcess at EX_PARTE_CE_CHECK step
    # @param kase [CertificationCase] - the case from business process
    # @return [void]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.determine_ce_hours_compliance(outcome, hours_data)
    end

    # FALLBACK: Called by CalculateComplianceJob for existing certifications
    # @param certification_id [String]
    # @return [Determination]
    def calculate(certification_id)
      certification = Certification.find(certification_id)
      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      certification.record_determination!(
        decision_method: :automated,
        reasons: [ reason_code_for(outcome) ],
        outcome: outcome,
        determination_data: build_determination_data(hours_data, "async_recalculation"),
        determined_at: Time.current
      )
    end

    private

    def determine_outcome(total_hours)
      total_hours >= TARGET_HOURS ? :compliant : :not_compliant
    end

    def reason_code_for(outcome)
      case outcome
      when :compliant then Determination::REASON_CODE_MAPPING[:hours_reported_compliant]
      when :not_compliant then Determination::REASON_CODE_MAPPING[:hours_reported_insufficient]
      end
    end

    def build_determination_data(hours_data, calculation_method)
      {
        calculation_type: "hours_based",
        calculation_method: calculation_method,
        total_hours: hours_data[:total_hours],
        target_hours: TARGET_HOURS,
        hours_by_category: hours_data[:hours_by_category],
        hours_by_source: hours_data[:hours_by_source],
        ex_parte_activity_ids: hours_data[:ex_parte_activity_ids],
        activity_ids: hours_data[:activity_ids],
        calculated_at: Time.current.iso8601
      }
    end

    # Aggregate hours from both ExParteActivity and approved Activity records
    # @param certification [Certification]
    # @return [Hash] with total_hours, hours_by_category, hours_by_source, etc.
    def aggregate_hours_for_certification(certification)
      lookback_period = certification.certification_requirements.continuous_lookback_period
      ex_parte_hours = aggregate_ex_parte_hours(certification.member_id, lookback_period)
      member_hours = aggregate_member_hours(certification)

      {
        total_hours: ex_parte_hours[:total] + member_hours[:total],
        hours_by_category: merge_category_hours(ex_parte_hours[:by_category], member_hours[:by_category]),
        hours_by_source: {
          ex_parte: ex_parte_hours[:total],
          activity: member_hours[:total]
        },
        ex_parte_activity_ids: ex_parte_hours[:ids],
        activity_ids: member_hours[:ids]
      }
    end

    def aggregate_ex_parte_hours(member_id, lookback_period)
      entries = ExParteActivity.for_member(member_id)

      # Filter to activities within the certification's lookback period
      if lookback_period.present?
        entries = entries.where(
          "period_start >= ? AND period_end <= ?",
          lookback_period.start.to_date,
          lookback_period.end.to_date.end_of_month
        )
      end

      {
        total: entries.sum(:hours).to_f,
        by_category: entries.group(:category).sum(:hours).transform_values(&:to_f),
        ids: entries.pluck(:id)
      }
    end

    def aggregate_member_hours(certification)
      # Only include hours from approved activity reports (member-reported hours)
      certification_case = CertificationCase.find_by(certification_id: certification.id)
      return empty_hours_result unless certification_case
      return empty_hours_result unless certification_case.activity_report_approval_status == "approved"

      form = ActivityReportApplicationForm.find_by(certification_case_id: certification_case.id)
      return empty_hours_result unless form

      activities = form.activities.where.not(hours: nil)
      {
        total: activities.sum(:hours).to_f,
        by_category: activities.group(:category).sum(:hours).transform_values(&:to_f),
        ids: activities.pluck(:id)
      }
    end

    def empty_hours_result
      { total: 0.0, by_category: {}, ids: [] }
    end

    def merge_category_hours(ex_parte, member)
      (ex_parte.keys | member.keys).each_with_object({}) do |category, result|
        result[category] = (ex_parte[category] || 0.0) + (member[category] || 0.0)
      end
    end
  end
end
