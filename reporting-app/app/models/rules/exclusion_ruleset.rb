# frozen_string_literal: true

module Rules
  # Eligibility rules for the community-engagement exclusions.
  class ExclusionRuleset < Strata::Rules::MedicaidRuleset
    AMERICAN_INDIAN_OR_ALASKA_NATIVE = [ "american_indian_or_alaska_native", "american_indian", "alaska_native" ].freeze

    # Pregnancy excludes from the due/parturition date through the following 12 months
    POSTPARTUM_EXCLUSION_MONTHS = 12

    # Former foster youth are excluded until this age
    FORMER_FOSTER_CARE_AGE_CAP = 26

    # Caretakers of a dependent child under this age are excluded (i.e. 13 or younger)
    CARETAKER_CHILD_AGE_THRESHOLD = 14

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

    # Caretakers are excluded if they are caretaking an infirm person during the certification month,
    # or caring for a dependent child under CARETAKER_CHILD_AGE_THRESHOLD. Both windows are evaluated
    # against the certification date at month granularity (consistent with the other date-based checks).
    def caretaker(dates_caretaking_infirm, dependent_children_birth_dates, certification_date)
      return if certification_date.nil?

      as_of = certification_date.beginning_of_month
      caretaking_infirm = Array(dates_caretaking_infirm).any? { |date| date.beginning_of_month == as_of }
      caring_for_child = Array(dependent_children_birth_dates).any? do |date_of_birth|
        as_of < date_of_birth + CARETAKER_CHILD_AGE_THRESHOLD.years
      end

      caretaking_infirm || caring_for_child
    end

    def eligible_for_exclusion(is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail, caretaker)
      facts = [ is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail, caretaker ]
      return if facts.all?(&:nil?)

      facts.any?
    end
  end
end
