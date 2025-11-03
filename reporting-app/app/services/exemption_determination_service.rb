# frozen_string_literal: true

class ExemptionDeterminationService
  class << self
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      eligibility_fact = evaluate_exemption_eligibility(certification)

      kase.determine_ex_parte_exemption(eligibility_fact)
    end

    private

    def evaluate_exemption_eligibility(certification)
      ruleset = Rules::ExemptionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      evaluation_date = extract_evaluation_date(certification)
      date_of_birth = extract_date_of_birth(certification)
      pregnancy_status = extract_pregnancy_status(certification)

      engine.set_facts(
        date_of_birth: date_of_birth,
        evaluated_on: evaluation_date,
        pregnancy_status: pregnancy_status
      )

      engine.evaluate(:eligible_for_exemption)
    end

    def extract_evaluation_date(certification)
      return nil unless certification.certification_requirements

      certification.certification_requirements.certification_date
    end

    def extract_date_of_birth(certification)
      return nil unless certification.member_data

      certification.member_data.date_of_birth
    end

    def extract_pregnancy_status(certification)
      return nil unless certification.member_data

      certification.member_data.pregnancy_status
    end
  end
end
