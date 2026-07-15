# frozen_string_literal: true

# Called by CertificationBusinessProcess at EXTERNAL_EXCEPTION_CHECK_STEP (after the exclusion
# check, before the community-engagement check).
#
# Service handles: evaluation, recording via model, and publishing events.
# Business process handles: transitions and notifications.
class ExceptionDeterminationService
  include Strata::VirtualActor

  # Each symbol names a private (member_data, certifiable_months) check method returning its reason
  # code, or nil. Order is evaluation order; the first applicable check wins. Mandatory checks run
  # first and are ungated; optional checks gate on ExternalException.enabled?.
  #
  # The mandatory checks migrated from the exclusion ruleset (pregnancy through inmate) except a
  # member when the corresponding exclusion would have been valid in any certifiable month
  # (certification_date is not consulted); for those monotonic in time, the earliest certifiable
  # month suffices (as in age_under_19).
  EXCEPTION_CHECKS = %i[
    pregnancy
    former_foster_care
    caretaker
    drug_treatment
    inmate
    age_under_19
    other_program
    inpatient_medical_care
    declared_emergency_county
    high_unemployment_county
    medical_travel
  ].freeze

  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      reason_codes = applicable_exception_reason_codes(certification)

      if reason_codes.any?
        kase.record_exception_determination(reason_codes, self)
        Strata::EventManager.publish("DeterminedExcepted", { case_id: kase.id, certification_id: kase.certification_id })
      else
        Strata::AuditLog.write!(
          action: "case.exception.denied",
          actor: self,
          subject: certification,
        )
        Strata::EventManager.publish("DeterminedNotExcepted", { case_id: kase.id, certification_id: kase.certification_id })
      end
    end

    private

    # Returns the reason code of the first applicable check (empty means not excepted). Checks run
    # lazily and stop at the first success, since a member needs only one exception reason.
    def applicable_exception_reason_codes(certification)
      member_data = certification.member_data
      return [] if member_data.nil?

      certifiable_months = certification.certification_requirements.months_that_can_be_certified.compact.map(&:beginning_of_month)
      return [] unless certifiable_months.present?

      reason_code = EXCEPTION_CHECKS.lazy.filter_map { |check| send(check, member_data, certifiable_months) }.first
      reason_code ? [ reason_code ] : []
    end

    # Migrated from the pregnancy exclusion. The postpartum window (due/parturition date +
    # POSTPARTUM_EXCLUSION_MONTHS) has no lower bound, so the earliest certifiable month decides.
    def pregnancy(member_data, certifiable_months)
      due_or_parturition_date = member_data.pregnancy_due_or_parturition_date
      return unless due_or_parturition_date

      postpartum_end = due_or_parturition_date + Rules::ExclusionRuleset::POSTPARTUM_EXCLUSION_MONTHS.months
      earliest_month = certifiable_months.sort.first
      return unless earliest_month <= postpartum_end

      Determination::REASON_CODE_MAPPING.fetch(:was_pregnant)
    end

    # Migrated from the former-foster-care exclusion: in foster care and under the age cap
    # (FORMER_FOSTER_CARE_AGE_CAP) during a certifiable month.
    def former_foster_care(member_data, certifiable_months)
      return unless member_data.was_in_foster_care
      dob = member_data.date_of_birth
      return unless dob

      age_cap_date = dob + Rules::ExclusionRuleset::FORMER_FOSTER_CARE_AGE_CAP.years
      earliest_month = certifiable_months.sort.first
      return unless earliest_month < age_cap_date

      Determination::REASON_CODE_MAPPING.fetch(:was_former_foster_care)
    end

    # Migrated from the caretaker exclusion: caretaking an infirm person during a certifiable month
    # (month-specific), or caring for a dependent child under CARETAKER_CHILD_AGE_THRESHOLD.
    def caretaker(member_data, certifiable_months)
      infirm_months = Array(member_data.dates_caretaking_infirm).compact.map(&:beginning_of_month)
      caretaking_infirm = (certifiable_months & infirm_months).present?

      threshold = Rules::ExclusionRuleset::CARETAKER_CHILD_AGE_THRESHOLD
      earliest_month = certifiable_months.sort.first
      caring_for_child = Array(member_data.dependent_children_birth_dates).compact.any? do |date_of_birth|
        earliest_month < date_of_birth + threshold.years
      end

      return unless caretaking_infirm || caring_for_child

      Determination::REASON_CODE_MAPPING.fetch(:was_caretaker)
    end

    # Migrated from the drug-treatment exclusion: in a drug/alcohol treatment program during a
    # certifiable month (month intersection).
    def drug_treatment(member_data, certifiable_months)
      return unless member_data.dates_in_drug_treatment.present?

      treatment_months = member_data.dates_in_drug_treatment.compact.map(&:beginning_of_month)
      return unless (certifiable_months & treatment_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:was_in_drug_treatment)
    end

    # Migrated from the inmate exclusion: each incarceration opens a bounded window [incarceration
    # month, +INMATE_BUFFER_MONTHS], so every certifiable month is tested against every window.
    def inmate(member_data, certifiable_months)
      return unless member_data.dates_incarcerated.present?

      buffer = Rules::ExclusionRuleset::INMATE_BUFFER_MONTHS
      incarceration_starts = member_data.dates_incarcerated.compact.map(&:beginning_of_month)
      excepted = certifiable_months.any? do |month|
        incarceration_starts.any? { |start| start <= month && month <= start + buffer.months }
      end
      return unless excepted

      Determination::REASON_CODE_MAPPING.fetch(:was_inmate)
    end

    # @return [String, nil] the reason code when the member was less than 19 in lookback period,
    #   otherwise nil.
    def age_under_19(member_data, certifiable_months)
      dob = member_data.date_of_birth
      return unless dob
      earliest_month = certifiable_months.sort.first
      return unless earliest_month - 19.years < dob

      Determination::REASON_CODE_MAPPING.fetch(:age_was_under_19)
    end

    # @return [String, nil] the reason code when the member was receiving inpatient medical care and
    #   the exception is enabled, otherwise nil.
    def inpatient_medical_care(member_data, certifiable_months)
      return unless ExternalException.enabled?(:inpatient_medical_care)
      return unless member_data.dates_receiving_inpatient_medical_care.present?

      inpatient_months = member_data.dates_receiving_inpatient_medical_care.compact.map(&:beginning_of_month)
      return unless (certifiable_months & inpatient_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:receiving_inpatient_medical_care)
    end

    # @return [String, nil] the reason code when the member resided in a declared-emergency county
    #   and the exception is enabled, otherwise nil.
    def declared_emergency_county(member_data, certifiable_months)
      return unless ExternalException.enabled?(:declared_emergency_county)
      return unless member_data.dates_in_declared_emergency_county.present?

      emergency_months = member_data.dates_in_declared_emergency_county.compact.map(&:beginning_of_month)
      return unless (certifiable_months & emergency_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_declared_emergency_county)
    end

    # @return [String, nil] the reason code when the member resided in a high-unemployment county and
    #   the exception is enabled, otherwise nil.
    def high_unemployment_county(member_data, certifiable_months)
      return unless ExternalException.enabled?(:high_unemployment_county)
      return unless member_data.dates_in_high_unemployment_county.present?

      high_unemployment_months = member_data.dates_in_high_unemployment_county.compact.map(&:beginning_of_month)
      return unless (certifiable_months & high_unemployment_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_high_unemployment_county)
    end

    # @return [String, nil] the reason code when the member was travelling for medical care (for
    #   themselves or a dependent) and the exception is enabled, otherwise nil.
    def medical_travel(member_data, certifiable_months)
      return unless ExternalException.enabled?(:medical_travel)
      return unless member_data.dates_traveling_for_medical_care.present?

      medical_travel_months = member_data.dates_traveling_for_medical_care.compact.map(&:beginning_of_month)
      return unless (certifiable_months & medical_travel_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:traveling_for_medical_care)
    end

    # @return [String, nil] the reason code when the member participated in either
    #   Medicare or Medicaid plans A or B, otherwise nil.
    def other_program(member_data, certifiable_months)
      return unless member_data.dates_participating_in_other_program.present?

      other_program_months = member_data.dates_participating_in_other_program.compact.map(&:beginning_of_month)
      return unless (certifiable_months & other_program_months).present?

      Determination::REASON_CODE_MAPPING.fetch(:participating_in_other_program)
    end
  end
end
