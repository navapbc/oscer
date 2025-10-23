# frozen_string_literal: true

module Rules
  # Implements eligibility rules for age-based Medicaid exemptions.
  # Inherits from Strata::Rules::MedicaidRuleset and adds exemption-specific logic.
  class ExemptionRuleset < Strata::Rules::MedicaidRuleset
    def age_under_19(age)
      return if age.nil?

      age < 19
    end

    def age_65_or_older(age)
      return if age.nil?

      age >= 65
    end

    def eligible_for_age_exemption(age_under_19, age_65_or_older)
      return if age_under_19.nil? && age_65_or_older.nil?

      [ age_under_19, age_65_or_older ].any?
    end
  end
end
