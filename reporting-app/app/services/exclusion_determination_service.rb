# frozen_string_literal: true

class ExclusionDeterminationService
  include Strata::VirtualActor
  class << self
    # Called by CertificationBusinessProcess at EXTERNAL_EXCLUSION_CHECK_STEP
    # Service handles: evaluation, recording via model, and publishing events
    # Business process handles: transitions and notifications
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      eligibility_fact = evaluate_exclusion_eligibility(certification)

      if eligibility_fact.value
        kase.record_exclusion_determination([ highest_priority_reason_code(eligibility_fact) ], self)
        Strata::EventManager.publish("DeterminedExcluded", { case_id: kase.id, certification_id: kase.certification_id })
      else
        Strata::AuditLog.write!(
          action: "case.exclusion.denied",
          actor: self,
          subject: certification,
        )
        Strata::EventManager.publish("DeterminedNotExcluded", { case_id: kase.id, certification_id: kase.certification_id })
      end
    end

    private

    def evaluate_exclusion_eligibility(certification)
      ruleset = Rules::ExclusionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      pregnancy_due_or_parturition_date = extract_pregnancy_due_or_parturition_date(certification)
      certification_date = certification.certification_requirements.certification_date
      race_ethnicity = extract_race_ethnicity(certification)
      veteran_disability_rating = extract_veteran_disability_status(certification)

      engine.set_facts(
        pregnancy_due_or_parturition_date: pregnancy_due_or_parturition_date,
        certification_date: certification_date,
        race_ethnicity: race_ethnicity,
        veteran_disability_rating: veteran_disability_rating
      )

      engine.evaluate(:eligible_for_exclusion)
    end

    # Of the exclusions that evaluated true, return the reason code of the single
    # highest-priority one (lowest Exclusion priority number wins).
    def highest_priority_reason_code(eligibility_fact)
      best_fact = eligibility_fact.reasons
        .select(&:value)
        .min_by { |fact| exclusion_priority(fact.name) }

      Determination::REASON_CODE_MAPPING.fetch(best_fact.name)
    end

    # Ruled exclusion ids match their ruleset fact names, so the fact name is the
    # config id. Raises (naming the fact) if a fact has no configured exclusion —
    # the fail-loud drift guard for the fact/config seam.
    def exclusion_priority(fact_name)
      exclusion = Exclusion.find(fact_name) ||
        raise(KeyError, "no configured exclusion for fact #{fact_name.inspect}")
      exclusion.fetch(:priority)
    end

    def extract_pregnancy_due_or_parturition_date(certification)
      return nil unless certification.member_data

      certification.member_data.pregnancy_due_or_parturition_date
    end

    def extract_race_ethnicity(certification)
      return nil unless certification.member_data

      certification.member_data.race_ethnicity
    end

    def extract_veteran_disability_status(certification)
      return nil unless certification.member_data&.va_icn.present?

      VeteranDisabilityService.new.get_disability_rating(icn: certification.member_data.va_icn)
    end
  end
end
