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
  # Every check but age_under_19 reads an API-supplied Certifications::MemberData::Exemption. Where
  # the exclusion check asks whether an exemption covers the certification month, the exception check
  # asks whether it covers any certifiable month (certification_date is not consulted).
  EXCEPTION_CHECKS = %i[
    pregnancy
    veteran_disability
    former_foster_care
    medically_frail
    caretaker
    tanf_snap_work
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

    # Migrated from the pregnancy exclusion, which treats pregnancy and postpartum as two exemptions
    # carrying their own periods.
    def pregnancy(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :pregnancy, certifiable_months) ||
                    covers_certifiable_month?(member_data, :postpartum, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_pregnant)
    end

    def veteran_disability(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :veteran_disability, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_veteran_with_disability)
    end

    def medically_frail(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :medical_condition, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_medically_frail)
    end

    def tanf_snap_work(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :meeting_tanf_or_snap_work, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_meeting_tanf_snap_work)
    end

    # Migrated from the former-foster-care exclusion: in foster care and under the age cap
    # (FORMER_FOSTER_CARE_AGE_CAP) during a certifiable month. The exemption's periods are not
    # consulted, matching the exclusion.
    def former_foster_care(member_data, certifiable_months)
      return unless member_data.verified_exemption(:former_foster_care)
      dob = member_data.date_of_birth
      return unless dob

      age_cap_date = dob + Rules::ExclusionRuleset::FORMER_FOSTER_CARE_AGE_CAP.years
      return unless certifiable_months.min < age_cap_date

      Determination::REASON_CODE_MAPPING.fetch(:was_former_foster_care)
    end

    # Caring for a disabled person during a certifiable month, or for a dependent child who was
    # already born and still under CARETAKER_CHILD_AGE_THRESHOLD in one of them.
    def caretaker(member_data, certifiable_months)
      threshold = Rules::ExclusionRuleset::CARETAKER_CHILD_AGE_THRESHOLD
      caring_for_child = periods(member_data, :caregiver_child).any? do |period|
        next unless period.period_start

        born = period.period_start.beginning_of_month
        turns_threshold = period.period_start + threshold.years
        certifiable_months.any? { |month| born <= month && month < turns_threshold }
      end

      return unless caring_for_child || covers_certifiable_month?(member_data, :caregiver_disability, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_caretaker)
    end

    def drug_treatment(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :substance_treatment, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:was_in_drug_treatment)
    end

    # Migrated from the inmate exclusion, which extends each incarceration period by
    # INMATE_BUFFER_MONTHS.
    def inmate(member_data, certifiable_months)
      buffer = Rules::ExclusionRuleset::INMATE_BUFFER_MONTHS
      return unless covers_certifiable_month?(member_data, :incarceration, certifiable_months, buffer_months: buffer)

      Determination::REASON_CODE_MAPPING.fetch(:was_inmate)
    end

    def age_under_19(member_data, certifiable_months)
      dob = member_data.date_of_birth
      return unless dob
      return unless certifiable_months.min - 19.years < dob

      Determination::REASON_CODE_MAPPING.fetch(:age_was_under_19)
    end

    def inpatient_medical_care(member_data, certifiable_months)
      return unless ExternalException.enabled?(:inpatient_medical_care)
      return unless covers_certifiable_month?(member_data, :inpatient_medical_care, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:receiving_inpatient_medical_care)
    end

    def declared_emergency_county(member_data, certifiable_months)
      return unless ExternalException.enabled?(:declared_emergency_county)
      return unless covers_certifiable_month?(member_data, :declared_emergency_county, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_declared_emergency_county)
    end

    def high_unemployment_county(member_data, certifiable_months)
      return unless ExternalException.enabled?(:high_unemployment_county)
      return unless covers_certifiable_month?(member_data, :high_unemployment_county, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_high_unemployment_county)
    end

    # Covers travel for the member's own medical care or a dependent's.
    def medical_travel(member_data, certifiable_months)
      return unless ExternalException.enabled?(:medical_travel)
      return unless covers_certifiable_month?(member_data, :travel_for_medical, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:traveling_for_medical_care)
    end

    # The other program is Medicare or Medicaid plan A or B.
    def other_program(member_data, certifiable_months)
      return unless covers_certifiable_month?(member_data, :other_program, certifiable_months)

      Determination::REASON_CODE_MAPPING.fetch(:participating_in_other_program)
    end

    # True when any certifiable month falls inside a period of the verified +type+ exemption,
    # optionally extended by +buffer_months+ past the period end. Month granularity and the
    # both-bounds-required rule match Rules::ExclusionRuleset#meets_end_condition.
    def covers_certifiable_month?(member_data, type, certifiable_months, buffer_months: 0)
      periods(member_data, type).any? do |period|
        next unless period.period_start && period.period_end

        window_start = period.period_start.beginning_of_month
        window_end = period.period_end.end_of_month + buffer_months.months
        certifiable_months.any? { |month| window_start <= month && month <= window_end }
      end
    end

    def periods(member_data, type)
      Array(member_data.verified_exemption(type)&.periods)
    end
  end
end
