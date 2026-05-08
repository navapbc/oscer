# frozen_string_literal: true

# Called by CertificationBusinessProcess at the external community engagement step.
# Aggregates hours and income, records a combined determination on the case, and publishes
# generic community-engagement Strata events (+DeterminedCommunityEngagementMet+ / +Insufficient+ / +ActionRequired+;
# see NotificationsEventListener).
class CommunityEngagementCheckService
  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      income_data = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)

      hours_ok = hours_compliant?(hours_data)
      income_ok = IncomeComplianceDeterminationService.compliant_for_total_income?(income_data[:total_income])

      kase.record_external_ce_combined_assessment(
        certification: certification,
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: hours_ok,
        income_ok: income_ok
      )

      publish_workflow_events(
        kase: kase,
        certification: certification,
        hours_data: hours_data,
        income_data: income_data,
        either_track_compliant: hours_ok || income_ok
      )
    end

    private

    def hours_compliant?(hours_data)
      HoursComplianceDeterminationService.compliant_for_total_hours?(hours_data[:total_hours])
    end

    def publish_workflow_events(kase:, certification:, hours_data:, income_data:, either_track_compliant:)
      payload_base = {
        case_id: kase.id,
        certification_id: certification.id
      }

      if either_track_compliant
        Strata::EventManager.publish("DeterminedCommunityEngagementMet", payload_base)
      elsif hours_data.dig(:hours_by_source, :external).to_f.positive?
        Strata::EventManager.publish("DeterminedCommunityEngagementInsufficient", payload_base.merge(
          hours_data: hours_data,
          income_data: income_data
        ))
      else
        Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", payload_base)
      end
    end
  end
end
