# frozen_string_literal: true

module Verification
  module Adapters
    # VA disability-rating verification data source.
    #
    # Wraps the existing VA transport layer (+VeteranAffairsAdapter+ +
    # +VaTokenManager+) in the {Verification::DataSource} contract: it owns its
    # ICN precondition, emits a flat outcome symbol, records redacted audit
    # data, and normalizes transport/token failures into a +:error+ result
    # instead of returning +nil+ (the previous fail-open behavior).
    #
    # NOTE: the 100%-rating interpretation duplicated here also still lives in
    # +Rules::ExclusionRuleset#is_veteran_with_disability+. That duplication is
    # intentional and temporary for this slice — resolved when the #756 data
    # source registry registers this adapter and a later orchestrator slice
    # wires +ExclusionDeterminationService+ to consume adapter outcomes (the
    # ruleset copy is then removed).
    class VaDisabilityRating < Verification::DataSource
      SOURCE = "va_disability_rating"
      OUTCOME_VETERAN_WITH_DISABILITY = :is_veteran_with_disability
      QUALIFYING_COMBINED_RATING = 100

      def self.declared_outcomes
        [ OUTCOME_VETERAN_WITH_DISABILITY ]
      end

      def initialize(adapter: VeteranAffairsAdapter.new, token_manager: VaTokenManager.new)
        @adapter = adapter
        @token_manager = token_manager
      end

      protected

      def precondition_met?(certification)
        certification.member_data&.va_icn.present?
      end

      def perform(certification:)
        access_token = @token_manager.get_access_token(icn: certification.member_data.va_icn)
        rating_data = @adapter.get_disability_rating(access_token: access_token)
        combined_rating = extract_combined_rating(rating_data)

        success_result(
          outcomes: outcomes_for(combined_rating),
          audit_data: audit_summary(rating_data, combined_rating)
        )
      end

      # Transport (auth, 5xx, rate limit — all subclass ApiError) and token
      # failures are caught by DataSource#call and become a :error result.
      def expected_error_classes
        [ VeteranAffairsAdapter::ApiError, VaTokenManager::TokenError ]
      end

      # Enrich the base error result with the source tag so :error audit_data is
      # never empty and is attributable to this data source.
      def error_result(error, audit_data: {})
        super(error, audit_data: audit_data.merge(source: SOURCE))
      end

      private

      def extract_combined_rating(rating_data)
        rating_data&.dig("data", "attributes", "combined_disability_rating")
      end

      # +to_i+ coercion intentionally mirrors +Rules::ExclusionRuleset#is_veteran_with_disability+.
      def outcomes_for(combined_rating)
        return [] if combined_rating.nil?

        combined_rating.to_i == QUALIFYING_COMBINED_RATING ? [ OUTCOME_VETERAN_WITH_DISABILITY ] : []
      end

      # Redacted summary only — never the full VA payload (which carries
      # individual diagnostic ratings / PHI).
      def audit_summary(rating_data, combined_rating)
        {
          source: SOURCE,
          combined_disability_rating: combined_rating,
          disability_rating_id: rating_data&.dig("data", "id")
        }
      end
    end
  end
end
