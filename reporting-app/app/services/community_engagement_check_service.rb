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

  # The in-hand assessment: both aggregates and their per-track verdicts. DataSourceCheckService
  # recomputes this when no data source produced an outcome, so the derivation lives here once
  # instead of in both steps, where the two could drift apart.
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
        income_ok: assessment.income_ok
      )

      Strata::EventManager.publish("DeterminedCommunityEngagementMet", payload_base)
    end

    # @param certification [Certification]
    # @return [Assessment]
    def assess(certification)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      income_data = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)

      Assessment.new(
        hours_data: hours_data,
        income_data: income_data,
        # A qualifying education enrollment meets the hours requirement outright, so it passes the
        # hours track instead of standing up a third one the determination payload has no shape for.
        hours_ok: HoursComplianceDeterminationService.compliant_for_monthly_hours?(hours_data[:hours_by_month]) ||
          HoursComplianceDeterminationService.education_enrollment_compliant?(certification),
        income_ok: IncomeComplianceDeterminationService.compliant_for_monthly_income?(income_data[:income_by_month])
      )
    end
  end
end
