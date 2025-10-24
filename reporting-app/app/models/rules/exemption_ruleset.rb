# frozen_string_literal: true

module Rules
  # Implements eligibility rules for age-based Medicaid exemptions.
  # Inherits from Strata::Rules::MedicaidRuleset and adds exemption-specific logic.
  class ExemptionRuleset < Strata::Rules::MedicaidRuleset
    def age_under_19(age)
      return if age.nil?

      age < 19
    end

    def eligible_for_age_exemption(age_under_19, age_over_65)
      [ age_under_19, age_over_65 ].any?
    end
  end
end
