# frozen_string_literal: true

class ExemptionDeterminationService
  class << self
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      date_of_birth = extract_date_of_birth(certification)

      eligible = evaluate_exemption_eligibility(date_of_birth)

      if eligible
        ActiveRecord::Base.transaction do
          kase.exemption_request_approval_status = "approved"
          kase.exemption_request_approval_status_updated_at = Time.current
          kase.close!

          Strata::EventManager.publish("DeterminedExempt", { case_id: kase.id })
        end
      else
        Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: kase.id })
      end
    end

    private

    def evaluate_exemption_eligibility(date_of_birth)
      return false unless date_of_birth

      ruleset = Rules::ExemptionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      engine.set_facts(
        date_of_birth: date_of_birth,
        evaluated_on: Date.current
      )

      eligibility_fact = engine.evaluate(:eligible_for_age_exemption)

      eligibility_fact.value
    end

    def extract_date_of_birth(certification)
      return nil unless certification.member_data

      certification.member_data.date_of_birth
    end
  end
end
