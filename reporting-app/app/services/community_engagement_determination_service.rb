# frozen_string_literal: true

# Ex parte community engagement (CE) check: evaluates hours and income against state thresholds.
# Compliance is satisfied if either dimension meets its target (OR). Publishes generic Strata events
# so the business process and notifications stay aligned for both paths.
class CommunityEngagementDeterminationService
  MET_EVENT = "DeterminedCommunityEngagementMet"
  INSUFFICIENT_EVENT = "DeterminedCommunityEngagementInsufficient"
  ACTION_REQUIRED_EVENT = "DeterminedActionRequired"

  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      income_data = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)

      hours_compliant = hours_compliant?(hours_data)
      income_compliant = income_compliant?(income_data)
      overall_met = hours_compliant || income_compliant

      ex_parte_hours_positive = hours_data[:hours_by_source][:ex_parte].to_f.positive?
      ex_parte_income_positive = income_data[:income_by_source][:income].positive?

      if overall_met
        record_met(kase, hours_compliant: hours_compliant, income_compliant: income_compliant, hours_data: hours_data,
                   income_data: income_data)
        publish_met(kase, certification, hours_compliant: hours_compliant, income_compliant: income_compliant)
      elsif !ex_parte_hours_positive && !ex_parte_income_positive
        kase.record_hours_compliance(:not_compliant, hours_data)
        kase.record_income_compliance(:not_compliant, income_data)
        publish_action_required(kase, certification)
      else
        kase.record_hours_compliance(:not_compliant, hours_data)
        kase.record_income_compliance(:not_compliant, income_data)
        publish_insufficient(
          kase,
          certification,
          hours_data: hours_data,
          income_data: income_data,
          hours_compliant: hours_compliant,
          income_compliant: income_compliant,
          ex_parte_hours_positive: ex_parte_hours_positive,
          ex_parte_income_positive: ex_parte_income_positive
        )
      end
    end

    private

    def hours_compliant?(hours_data)
      hours_data[:total_hours].to_d >= HoursComplianceDeterminationService::TARGET_HOURS
    end

    def income_compliant?(income_data)
      income_data[:total_income].to_d >= IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
    end

    def record_met(kase, hours_compliant:, income_compliant:, hours_data:, income_data:)
      if hours_compliant
        kase.record_hours_compliance(:compliant, hours_data)
      else
        kase.record_income_compliance(:compliant, income_data)
      end
    end

    def publish_met(kase, certification, hours_compliant:, income_compliant:)
      satisfied_by =
        if hours_compliant && income_compliant
          :both
        elsif hours_compliant
          :hours
        else
          :income
        end

      Strata::EventManager.publish(MET_EVENT, {
        case_id: kase.id,
        certification_id: certification.id,
        satisfied_by: satisfied_by
      })
    end

    def publish_action_required(kase, certification)
      Strata::EventManager.publish(ACTION_REQUIRED_EVENT, {
        case_id: kase.id,
        certification_id: certification.id
      })
    end

    def publish_insufficient(kase, certification, hours_data:, income_data:,
                             hours_compliant:, income_compliant:,
                             ex_parte_hours_positive:, ex_parte_income_positive:)
      show_hours = !hours_compliant && ex_parte_hours_positive
      show_income = !income_compliant && ex_parte_income_positive

      Strata::EventManager.publish(INSUFFICIENT_EVENT, {
        case_id: kase.id,
        certification_id: certification.id,
        hours_data: hours_data,
        income_data: income_data,
        show_hours_insufficient: show_hours,
        show_income_insufficient: show_income
      })
    end
  end
end
