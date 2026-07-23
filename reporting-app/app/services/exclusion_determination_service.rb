# frozen_string_literal: true

class ExclusionDeterminationService
  include Strata::VirtualActor
  class << self
    # Called by CertificationBusinessProcess at EXTERNAL_EXCLUSION_CHECK_STEP.
    #
    # Takes the highest-priority exclusion from the rules engine, then lets the
    # verification data sources improve on it. Records an exclusion if one
    # applies, otherwise an exception if a source emitted one, otherwise nothing.
    #
    # Service handles: evaluation, recording via model, and publishing events.
    # Business process handles: transitions and notifications.
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)

      current_best = rules_engine_best_exclusion(certification)
      current_best, exception_keys = consult_data_sources(certification, current_best)

      if current_best
        kase.record_exclusion_determination([ reason_code(current_best[:key]) ], self)
        publish(kase, "DeterminedExcluded")
      elsif exception_keys.any?
        kase.record_exception_determination([ reason_code(exception_keys.first) ], self)
        publish(kase, "DeterminedExcepted")
      else
        Strata::AuditLog.write!(action: "case.exclusion.denied", actor: self, subject: certification)
        publish(kase, "DeterminedNotExcluded")
      end
    end

    private

    def publish(kase, event)
      Strata::EventManager.publish(event, { case_id: kase.id, certification_id: kase.certification_id })
    end

    # The highest-priority exclusion (lowest priority number) the rules engine
    # found, as { key:, priority: }, or nil when none applies.
    def rules_engine_best_exclusion(certification)
      eligibility_fact = evaluate_exclusion_eligibility(certification)
      return nil unless eligibility_fact.value

      eligibility_fact.reasons
        .select(&:value)
        .map { |fact| { key: fact.name, priority: exclusion_priority(fact.name) } }
        .min_by { |scored| scored[:priority] }
    end

    # Walks the enabled data sources by best declared priority first, calling one
    # only while the best exclusion it could emit could still outrank the running
    # best. Returns the (possibly improved) best exclusion and any exception
    # outcomes emitted along the way. Exception-only sources are skipped here.
    def consult_data_sources(certification, current_best)
      exception_keys = []

      candidates = data_sources
        .map { |source| { source: source, priority: best_declared_priority(source) } }
        .select { |candidate| candidate[:priority] }
        .sort_by { |candidate| candidate[:priority] }

      candidates.each do |candidate|
        break unless outranks?(candidate, current_best)

        result = candidate[:source].new.call(certification: certification)
        emitted = best_exclusion(result.outcomes)
        current_best = emitted if emitted && outranks?(emitted, current_best)
        exception_keys.concat(exception_outcomes(result.outcomes))
      end

      [ current_best, exception_keys ]
    end

    def data_sources
      Rails.application.config.verification_data_sources
        .select { |entry| entry[:enabled] }
        .map { |entry| entry[:adapter_class].constantize }
    end

    def best_declared_priority(source)
      source.declared_outcomes.filter_map { |key| exclusion_priority_or_nil(key) }.min
    end

    # The highest-priority exclusion among emitted outcome keys, as { key:,
    # priority: }, or nil when none resolve to an exclusion.
    def best_exclusion(outcomes)
      outcomes
        .map { |key| { key: key, priority: exclusion_priority_or_nil(key) } }
        .select { |scored| scored[:priority] }
        .min_by { |scored| scored[:priority] }
    end

    # Emitted outcome keys that are not exclusions (e.g. the *_excepted facts).
    def exception_outcomes(outcomes)
      outcomes.reject { |key| exclusion_priority_or_nil(key) }
    end

    # Lower priority number wins; nil current_best means nothing yet, so any
    # candidate outranks it. Both are { priority: } hashes.
    def outranks?(candidate, current_best)
      current_best.nil? || candidate[:priority] < current_best[:priority]
    end

    def reason_code(key)
      Determination::REASON_CODE_MAPPING.fetch(key)
    end

    def evaluate_exclusion_eligibility(certification)
      ruleset = Rules::ExclusionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      engine.set_facts(
        pregnancy_due_or_parturition_date: extract_attribute(certification, :pregnancy_due_or_parturition_date),
        certification_date: certification.certification_requirements.certification_date,
        race_ethnicity: extract_attribute(certification, :race_ethnicity),
        veteran_with_disability: extract_attribute(certification, :veteran_with_disability),
        was_in_foster_care: extract_attribute(certification, :was_in_foster_care),
        date_of_birth: extract_attribute(certification, :date_of_birth),
        currently_medically_frail: extract_attribute(certification, :currently_medically_frail),
        dates_caretaking_infirm: extract_attribute(certification, :dates_caretaking_infirm),
        dependent_children_birth_dates: extract_attribute(certification, :dependent_children_birth_dates),
        meeting_tanf_or_snap_work: extract_attribute(certification, :meeting_tanf_or_snap_work),
        dates_in_drug_treatment: extract_attribute(certification, :dates_in_drug_treatment),
        dates_incarcerated: extract_attribute(certification, :dates_incarcerated)
      )

      engine.evaluate(:eligible_for_exclusion)
    end

    # Ruled exclusion ids match their ruleset fact names, so the fact name is the
    # config id. Raises (naming the fact) if a fact has no configured exclusion —
    # the fail-loud drift guard for the fact/config seam.
    def exclusion_priority(fact_name)
      exclusion = Exclusion.find(fact_name) ||
        raise(KeyError, "no configured exclusion for fact #{fact_name.inspect}")
      exclusion.fetch(:priority)
    end

    # Non-raising sibling of exclusion_priority: nil for non-exclusion keys.
    def exclusion_priority_or_nil(key)
      Exclusion.find(key)&.fetch(:priority)
    end

    def extract_attribute(certification, attribute)
      return nil unless certification.member_data

      certification.member_data.send(attribute)
    end
  end
end
