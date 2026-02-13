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

    def is_veteran_with_disability(veteran_disability_rating)
      return if veteran_disability_rating.nil?

      combined_rating = veteran_disability_rating.dig("data", "attributes", "combined_disability_rating")
      return false if combined_rating.nil?

      combined_rating.to_i == 100
    end

    def eligible_for_exemption(age_under_19, age_over_65, is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability)
      facts = [ age_under_19, age_over_65, is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability ]
      return if facts.all?(&:nil?)

      facts.any?
    end
  end
end
