# frozen_string_literal: true

# Called by CertificationBusinessProcess at EXTERNAL_EXCEPTION_CHECK_STEP (after the exclusion
# check, before the community-engagement check).
#
# Service handles: evaluation, recording via model, and publishing events.
# Business process handles: transitions and notifications.
class ExceptionDeterminationService
  include Strata::VirtualActor
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

    # Runs the exception checks against the member's data and returns a list containing the first reason code that
    # applies. No checks are implemented yet, so this returns [] and no member is excepted. Each check's
    # own story adds its predicate and reason code here.
    def applicable_exception_reason_codes(_certification)
      []
    end
  end
end
