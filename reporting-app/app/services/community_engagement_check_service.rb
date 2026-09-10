# frozen_string_literal: true

# Called by CertificationBusinessProcess at the external community engagement step. Aggregates the
# in-hand hours and income (inbound-pushed plus member-reported) and decides whether either track
# satisfies the community-engagement requirement.
#
# Met: records the combined determination and publishes +DeterminedCommunityEngagementMet+.
#
# Not met: records NOTHING and publishes +DeterminedCommunityEngagementNotMet+, handing the member to
# the trailing VERIFICATION_DATA_SOURCE_CHECK_STEP, which owns the negative determination and the
# report_activities handoff (OSCER-805). That event has no NotificationsEventListener subscription:
# the listener binds to event NAMES with no step awareness, so a member-facing negative here would
# email the member before the sources were consulted, and again if one then excepted them.
class CommunityEngagementCheckService
  include Strata::VirtualActor

  # The in-hand assessment: each aggregate and its per-track verdict. DataSourceCheckService
  # recomputes this when no data source produced an outcome, so the derivation lives here once
  # instead of in both steps, where the two could drift apart.
  #
  # +combined_hours_data+ and +combined_hours_ok+ are both nil unless the fallback was consulted
  # (see +assess+), so an unweighed track is never mistaken for one that fell short.
  Assessment = Struct.new(:hours_data, :income_data, :combined_hours_data,
                          :hours_ok, :income_ok, :combined_hours_ok, keyword_init: true) do
    def met?
      hours_ok || income_ok || combined_hours_ok
    end
  end

  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      assessment = assess(certification)
      payload_base = { case_id: kase.id, certification_id: certification.id }

      unless assessment.met?
        return Strata::EventManager.publish("DeterminedCommunityEngagementNotMet", payload_base)
      end

      kase.record_external_ce_combined_assessment(
        actor: self,
        certification: certification,
        hours_data: assessment.hours_data,
        income_data: assessment.income_data,
        hours_ok: assessment.hours_ok,
        income_ok: assessment.income_ok,
        combined_hours_data: assessment.combined_hours_data,
        combined_hours_ok: assessment.combined_hours_ok
      )

      Strata::EventManager.publish("DeterminedCommunityEngagementMet", payload_base)
    end

    # @param certification [Certification]
    # @return [Assessment]
    def assess(certification)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      income_data = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)
      # A qualifying education enrollment meets the hours requirement outright, so it passes the
      # hours track instead of standing up a track of its own the determination payload has no shape for.
      hours_ok = HoursComplianceDeterminationService.compliant_for_monthly_hours?(hours_data[:hours_by_month]) ||
        HoursComplianceDeterminationService.education_enrollment_compliant?(certification)
      income_ok = IncomeComplianceDeterminationService.compliant_for_monthly_income?(income_data[:income_by_month])

      # A member already carried by one of the two tracks leaves the fallback unconsulted, and its
      # two fields unset, rather than recorded as a track that was weighed and fell short.
      return Assessment.new(hours_data:, income_data:, hours_ok:, income_ok:) if hours_ok || income_ok

      # The last resort: earned income stands for the hours behind it, so a member short on both
      # tracks can still clear the hours threshold on reported and imputed hours together. It
      # imputes hours nobody reported, so it is work worth doing only where it changes the answer.
      # The aggregate is carried beside +hours_data+ rather than replacing it, so the determination
      # keeps reported hours distinguishable from imputed ones.
      combined_hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(
        certification, with_income_conversion: true
      )

      Assessment.new(
        hours_data:, income_data:, hours_ok:, income_ok:,
        combined_hours_data:,
        combined_hours_ok: HoursComplianceDeterminationService
          .compliant_for_monthly_hours?(combined_hours_data[:hours_by_month])
      )
    end
  end
end
