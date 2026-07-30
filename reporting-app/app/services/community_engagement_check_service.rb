# frozen_string_literal: true

# Called by CertificationBusinessProcess at the external community engagement step.
# Aggregates hours and income, records a combined determination on the case, and publishes
# generic community-engagement Strata events (+DeterminedCommunityEngagementMet+ / +Insufficient+ / +ActionRequired+;
# see NotificationsEventListener).
class CommunityEngagementCheckService
  include Strata::VirtualActor

  # The in-hand assessment: both aggregates and their per-track verdicts. Extracted from #determine
  # so a second step can reuse the derivation instead of repeating it, where the two could drift.
  Assessment = Struct.new(:hours_data, :income_data, :hours_ok, :income_ok, keyword_init: true) do
    def met?
      hours_ok || income_ok
    end
  end

  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      assessment = assess(certification)

      kase.record_external_ce_combined_assessment(
        actor: self,
        certification: certification,
        hours_data: assessment.hours_data,
        income_data: assessment.income_data,
        hours_ok: assessment.hours_ok,
        income_ok: assessment.income_ok
      )

      publish_workflow_events(
        kase: kase,
        certification: certification,
        hours_data: assessment.hours_data,
        income_data: assessment.income_data,
        either_track_compliant: assessment.met?
      )
    end

    # @param certification [Certification]
    # @return [Assessment]
    def assess(certification)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      income_data = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)

      Assessment.new(
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: HoursComplianceDeterminationService.compliant_for_total_hours?(hours_data[:total_hours]),
        income_ok: IncomeComplianceDeterminationService.compliant_for_total_income?(income_data[:total_income])
      )
    end

    private

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
