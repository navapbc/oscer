# frozen_string_literal: true

module Verification
  module Adapters
    # Mock data source for the community-engagement half of the ordered non-exclusion pass
    # (OSCER-805). Attests the requirement is met rather than reporting hours, and declares no
    # exclusion outcome, so only the orchestrator consults it.
    #
    # Keys off the member's email, NOT va_icn, and must stay that way: MockDrugTreatment runs at the
    # earlier exclusion step and ends the case for 7 of 10 va_icn last digits, leaving only even ones,
    # which are MockEmergencyCounty's — a va_icn-keyed trigger here would be starved before it ran.
    # Guarded by certification_business_process_reachability_spec. Email is as inert as va_icn (no
    # determination path reads it); the substring idiom follows Auth::MockAdapter ("unconfirmed").
    #
    # A real source must NOT copy this: email describes the member and also joins them to their
    # certification (Certification.find_by_member_email), so one member-influenceable attribute both
    # selects the record and drives a favorable outcome. Fine synthetically, never for real.
    class MockCommunityEngagement < Verification::DataSource
      SOURCE = "mock_community_engagement"
      OUTCOME_CE_MET = :hours_reported_compliant
      TRIGGER_EMAIL_SUBSTRING = "ce-met"

      def self.declared_outcomes
        [ OUTCOME_CE_MET ]
      end

      protected

      def precondition_met?(certification)
        certification.member_email.present?
      end

      def perform(certification:)
        success_result(
          outcomes: outcomes_for(certification.member_email),
          audit_data: { source: SOURCE }
        )
      end

      private

      def outcomes_for(email)
        email.downcase.include?(TRIGGER_EMAIL_SUBSTRING) ? [ OUTCOME_CE_MET ] : []
      end
    end
  end
end
