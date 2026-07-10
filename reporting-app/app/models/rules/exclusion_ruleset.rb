# frozen_string_literal: true

module Rules
  # Eligibility rules for the community-engagement exclusions.
  class ExclusionRuleset < Strata::Rules::MedicaidRuleset
    AMERICAN_INDIAN_OR_ALASKA_NATIVE = [ "american_indian_or_alaska_native", "american_indian", "alaska_native" ].freeze

    # Pregnancy excludes from the due/parturition date through the following 12 months
    POSTPARTUM_EXCLUSION_MONTHS = 12

    # Former foster youth are excluded until this age
    FORMER_FOSTER_CARE_AGE_CAP = 26

    def is_pregnant(pregnancy_due_or_parturition_date, certification_date)
      return if pregnancy_due_or_parturition_date.nil?
      return if certification_date.nil?

      exclusion_end = pregnancy_due_or_parturition_date + POSTPARTUM_EXCLUSION_MONTHS.months
      certification_date.beginning_of_month <= exclusion_end
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

    # Former foster youth are excluded until age FORMER_FOSTER_CARE_AGE_CAP, evaluated against the
    # certification date at month granularity (consistent with pregnancy).
    def former_foster_care(was_in_foster_care, date_of_birth, certification_date)
      return unless was_in_foster_care
      return if date_of_birth.nil? || certification_date.nil?

      certification_date.beginning_of_month < date_of_birth + FORMER_FOSTER_CARE_AGE_CAP.years
    end

    # Members determined currently medically frail are excluded.
    def medically_frail(currently_medically_frail)
      currently_medically_frail
    end

    def eligible_for_exclusion(is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail)
      facts = [ is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail ]
      return if facts.all?(&:nil?)

      facts.any?
    end
  end
end
