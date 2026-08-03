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

    # Incarceration excludes through this many months after the incarceration month
    INMATE_BUFFER_MONTHS = 3

    def is_pregnant(pregnancy, postpartum, certification_date)
      meets_end_condition(pregnancy, certification_date) || meets_end_condition(postpartum, certification_date)
    end

    def is_american_indian_or_alaska_native(american_indian_or_alaska_native)
      american_indian_or_alaska_native.present?
    end

    def is_veteran_with_disability(veteran_disability, certification_date)
      meets_end_condition(veteran_disability, certification_date)
    end

    # Former foster youth are excluded until age FORMER_FOSTER_CARE_AGE_CAP, evaluated against the
    # certification date at month granularity (consistent with pregnancy).
    def former_foster_care(was_in_foster_care, date_of_birth, certification_date)
      return if was_in_foster_care.nil?
      return if date_of_birth.nil? || certification_date.nil?

      certification_date.beginning_of_month < date_of_birth + FORMER_FOSTER_CARE_AGE_CAP.years
    end

    # Members determined currently medically frail are excluded.
    def medically_frail(medical_condition, certification_date)
      meets_end_condition(medical_condition, certification_date)
    end

    # Caretakers are excluded if they are caretaking an infirm person during the certification month,
    # or caring for a dependent child under CARETAKER_CHILD_AGE_THRESHOLD. Both windows are evaluated
    # against the certification date at month granularity (consistent with the other date-based checks).
    def caretaker(caregiver_disability, caregiver_child, certification_date)
      return if certification_date.nil?

      cert_month = certification_date.beginning_of_month
      caring_for_child = Array(caregiver_child&.periods || []).any? do |period|
        cert_month < period.period_start + CARETAKER_CHILD_AGE_THRESHOLD.years
      end

      caring_for_child || meets_end_condition(caregiver_disability, certification_date)
    end

    # Members already meeting SNAP/TANF work requirements are excluded.
    def tanf_snap_work(meeting_tanf_or_snap_work, certification_date)
      meets_end_condition(meeting_tanf_or_snap_work, certification_date)
    end

    # Members participating in a drug/alcohol treatment program during the certification month are
    # excluded (month granularity, consistent with the other date-based checks).
    def drug_treatment(substance_treatment, certification_date)
      meets_end_condition(substance_treatment, certification_date)
    end

    # Incarcerated members are excluded while incarcerated and for INMATE_BUFFER_MONTHS afterward,
    # evaluated against the certification date at month granularity.
    def inmate(incarceration, certification_date)
      return if certification_date.nil?
      return if incarceration.nil?

      cert_month = certification_date.beginning_of_month
      Array(incarceration.periods).any? do |period|
        next unless period.period_end
        cert_month <= period.period_end.end_of_month + INMATE_BUFFER_MONTHS.months
      end
    end

    def eligible_for_exclusion(is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail, caretaker, tanf_snap_work, drug_treatment, inmate)
      facts = [ is_pregnant, is_american_indian_or_alaska_native, is_veteran_with_disability, former_foster_care, medically_frail, caretaker, tanf_snap_work, drug_treatment, inmate ]
      return if facts.all?(&:nil?)

      facts.any?
    end

    private

    def meets_end_condition(member_data_exemption, certification_date)
      return if certification_date.nil?
      return if member_data_exemption.nil?

      cert_month = certification_date.beginning_of_month
      Array(member_data_exemption.periods).any? do |period|
        next unless period.period_end
        cert_month <= period.period_end.end_of_month
      end
    end
  end
end
