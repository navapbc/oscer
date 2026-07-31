# frozen_string_literal: true

# Called by CertificationBusinessProcess at VERIFICATION_DATA_SOURCE_CHECK_STEP (OSCER-805).
# Consults the ordered non-exclusion data sources via {Verification::DataSourceOrchestrator} and
# records the winning outcome, or concludes non-compliance and hands the member to
# report_activities. This is where OSCER calls OUT; the preceding steps assess data already in hand.
#
# The negative is recorded HERE, not at the community-engagement check: a member a source goes on to
# except would otherwise be left with a superseded +not_compliant+ row and a false
# +case.activity_report.denied+ audit line. Exactly one determination per member.
class DataSourceCheckService
  include Strata::VirtualActor

  # Raised when a source emits an outcome with no determination shape here. Reachable by config: the
  # loader lets an order-bearing source declare exclusion outcomes, which this pass cannot rank.
  class UnsupportedOutcomeError < StandardError; end

  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      orchestration = Verification::DataSourceOrchestrator.evaluate(certification)

      return record_source_attestation(kase, orchestration) if orchestration.satisfied?

      # An errored source is not a source that said "no". Two gaps, neither covered by
      # https://github.com/navapbc/oscer/issues/810 (scoped to ExclusionDeterminationService): this
      # log is the only record that evidence was missing, since the row below is indistinguishable
      # from a clean negative; and an undeclared error propagates by design, but Strata's
      # execute_current_step is +rescue Exception+ plus a log, so the case strands with no
      # determination, notification or staff task. Both need a ticket before a real adapter lands.
      log_failed_attempts(kase, orchestration)

      record_requirement_not_met(kase, certification)
    end

    private

    def log_failed_attempts(kase, orchestration)
      failed = orchestration.attempted.select { |attempt| attempt[:result].status == Verification::DataSourceResult::STATUS_ERROR }
      return if failed.empty?

      Rails.logger.warn(
        "#{name}: recording community-engagement non-compliance for case #{kase.id} while " \
        "#{failed.count} verification data source(s) failed: " \
        "#{failed.map { |a| "#{a[:source_id]}=#{a[:result].error_code}" }.join(', ')}. " \
        "A source that would have produced an outcome may not have been reached."
      )
    end

    def record_source_attestation(kase, orchestration)
      outcomes = orchestration.result.outcomes
      validate_outcomes!(outcomes, orchestration.source_id)
      data_source = orchestration.source_id.to_s

      exception_keys = outcomes & Determination::EXCEPTION_OUTCOME_KEYS

      # An exception outranks a CE attestation from the same source, mirroring the flow's own order.
      if exception_keys.any?
        # One reason, like ExclusionDeterminationService and ExceptionDeterminationService. The
        # source's first emitted key wins, since Array#& above keeps the receiver's order.
        kase.record_exception_determination(reason_codes(exception_keys.first(1)), self, data_source: data_source)
        publish(kase, "DeterminedExcepted")
      else
        # All of them, unlike above: hours-met and income-met corroborate rather than compete.
        kase.record_data_source_ce_determination(reason_codes(outcomes), self, data_source: data_source)
        publish(kase, "DeterminedCommunityEngagementMet")
      end
    end

    # No source produced an outcome, so the in-hand assessment stands. Recomputed because Strata
    # hands a system_process only the case, never the event; shares
    # CommunityEngagementCheckService.assess so the two steps cannot derive it differently.
    def record_requirement_not_met(kase, certification)
      assessment = CommunityEngagementCheckService.assess(certification)

      kase.record_external_ce_combined_assessment(
        actor: self,
        certification: certification,
        hours_data: assessment.hours_data,
        income_data: assessment.income_data,
        hours_ok: assessment.hours_ok,
        income_ok: assessment.income_ok
      )

      # The Insufficient/ActionRequired split moved here with the negative determination, so both
      # stay with whichever step concludes non-compliance.
      payload = { case_id: kase.id, certification_id: certification.id }

      if assessment.hours_data.dig(:hours_by_source, :external).to_f.positive?
        Strata::EventManager.publish("DeterminedCommunityEngagementInsufficient", payload.merge(
          hours_data: assessment.hours_data,
          income_data: assessment.income_data
        ))
      else
        Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", payload)
      end
    end

    def validate_outcomes!(outcomes, source_id)
      unsupported = outcomes - Determination::NON_EXCLUSION_OUTCOME_KEYS
      return if unsupported.empty?

      raise UnsupportedOutcomeError,
        "verification data source '#{source_id}' emitted outcome(s) #{unsupported.map(&:to_s)} with no " \
        "determination shape in #{name}; expected exception keys (#{Determination::EXCEPTION_OUTCOME_KEYS.map(&:to_s)}) " \
        "or community-engagement keys (#{Determination::CE_OUTCOME_KEYS.map(&:to_s)})"
    end

    def reason_codes(outcome_keys)
      outcome_keys.map { |key| Determination::REASON_CODE_MAPPING.fetch(key) }
    end

    def publish(kase, event)
      Strata::EventManager.publish(event, { case_id: kase.id, certification_id: kase.certification_id })
    end
  end
end
