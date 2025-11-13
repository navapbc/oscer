# frozen_string_literal: true

module Rules
  # Implements eligibility rules for age-based Medicaid exemptions.
  # Inherits from Strata::Rules::MedicaidRuleset and adds exemption-specific logic.
  class ExemptionRuleset < Strata::Rules::MedicaidRuleset
    AMERICAN_INDIAN_OR_ALASKA_NATIVE = [ "american_indian_or_alaska_native", "american_indian", "alaska_native" ].freeze

    def age_under_19(age)
      return if age.nil?

      age < 19
    end

    def is_pregnant(pregnancy_status)
      return if pregnancy_status.nil?

      pregnancy_status
    end

    def is_american_indian_or_alaska_native(race_ethnicity)
      return if race_ethnicity.nil?

      AMERICAN_INDIAN_OR_ALASKA_NATIVE.include?(race_ethnicity.downcase.gsub(/\s+/, "_"))
    end

    def eligible_for_exemption(age_under_19, age_over_65, is_pregnant, is_american_indian_or_alaska_native)
      return if [ age_under_19, age_over_65, is_pregnant, is_american_indian_or_alaska_native ].all?(&:nil?)

      [ age_under_19, age_over_65, is_pregnant, is_american_indian_or_alaska_native ].any?
    end
  end
end
