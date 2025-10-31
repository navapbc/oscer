# frozen_string_literal: true

class ExemptionDeterminationService
  class << self
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      evaluation_date = certification.certification_requirements.certification_date
      date_of_birth = extract_date_of_birth(certification)
      eligibility_fact = evaluate_exemption_eligibility(date_of_birth, evaluation_date)

      kase.determine_ex_parte_exemption(eligibility_fact)
    end

    private

    def evaluate_exemption_eligibility(date_of_birth, evaluation_date)
      return Strata::RulesEngine::Fact.new("no-op", false) unless date_of_birth

      ruleset = Rules::ExemptionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      engine.set_facts(
        date_of_birth: date_of_birth,
        evaluated_on: evaluation_date
      )

      engine.evaluate(:eligible_for_age_exemption)
    end

    def extract_date_of_birth(certification)
      return nil unless certification.member_data

      certification.member_data.date_of_birth
    end
  end
end
