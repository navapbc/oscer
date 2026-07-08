# frozen_string_literal: true

# Called by CertificationBusinessProcess at EXTERNAL_EXCEPTION_CHECK_STEP (after the exclusion
# check, before the community-engagement check).
#
# Service handles: evaluation, recording via model, and publishing events.
# Business process handles: transitions and notifications.
class ExceptionDeterminationService
  include Strata::VirtualActor

  # Each symbol names a private check method taking certification and returning its reason code when
  # the exception applies (and is enabled), or nil otherwise. Add a check by adding its symbol here
  # and defining the matching method. Order is the evaluation order; the first applicable check wins.
  EXCEPTION_CHECKS = %i[
    age_under_19
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

    # Returns an array holding the reason code for the first exception check that applies (empty when
    # none apply, which leaves the member not excepted). A member needs only one exception reason, so
    # checks run lazily and stop at the first success. Each check is a plain method (no rules engine)
    # that gates itself on ExternalException.enabled?, so a deployment can disable any optional
    # exception via configuration.
    def applicable_exception_reason_codes(certification)
      member_data = certification.member_data
      return [] if member_data.nil?

      reason_code = EXCEPTION_CHECKS.lazy.filter_map { |check| send(check, certification) }.first
      reason_code ? [ reason_code ] : []
    end

    # @return [String, nil] the reason code when the member was less than 19 in lookback period,
    #   otherwise nil.
    def age_under_19(certification)
      dob = certification.member_data.date_of_birth
      return unless dob
      earliest_month = certification.certification_requirements.months_that_can_be_certified.sort.first
      return unless earliest_month - 19.years < dob

      Determination::REASON_CODE_MAPPING.fetch(:age_was_under_19)
    end

    # @return [String, nil] the reason code when the member is receiving inpatient medical care and
    #   the exception is enabled, otherwise nil.
    def inpatient_medical_care(certification)
      return unless ExternalException.enabled?(:inpatient_medical_care)
      return unless certification.member_data.receiving_inpatient_medical_care

      Determination::REASON_CODE_MAPPING.fetch(:receiving_inpatient_medical_care)
    end

    # @return [String, nil] the reason code when the member resides in a declared-emergency county
    #   and the exception is enabled, otherwise nil.
    def declared_emergency_county(certification)
      return unless ExternalException.enabled?(:declared_emergency_county)
      return unless certification.member_data.resides_in_declared_emergency_county

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_declared_emergency_county)
    end

    # @return [String, nil] the reason code when the member resides in a high-unemployment county and
    #   the exception is enabled, otherwise nil.
    def high_unemployment_county(certification)
      return unless ExternalException.enabled?(:high_unemployment_county)
      return unless certification.member_data.resides_in_high_unemployment_county

      Determination::REASON_CODE_MAPPING.fetch(:resides_in_high_unemployment_county)
    end

    # @return [String, nil] the reason code when the member is travelling for medical care (for
    #   themselves or a dependent) and the exception is enabled, otherwise nil.
    def medical_travel(certification)
      return unless ExternalException.enabled?(:medical_travel)
      return unless certification.member_data.traveling_for_medical_care

      Determination::REASON_CODE_MAPPING.fetch(:traveling_for_medical_care)
    end
  end
end
