# frozen_string_literal: true

module Verification
  # Evaluates the ordered non-exclusion verification data sources for a
  # certification, stopping at the first source that produces a positive result.
  #
  # This is the consumer the Data Source registry (VerificationDataSourcesLoader)
  # was built for but deferred: the registry stores each source's call +order+ and
  # says "Consumers (orchestrator) must sort by order themselves." This does that.
  #
  # "Non-exclusion" sources are the order-bearing entries: by loader convention an
  # exclusion-only source has +order: nil+ (its outcome ranking is owned by
  # Exclusion.priority_order, not by call order), so it is not part of this pass.
  # Hybrid sources that mix exclusion and non-exclusion results are out of scope.
  #
  # The pass calls sources in ascending +order+ (the loader guarantees +order+
  # distinctness at boot, so the sort is deterministic) and stops at the first
  # {DataSourceResult} that is +success?+ AND carries at least one outcome. A
  # +:success+ with empty outcomes is a documented "called, no matching outcome"
  # negative, so it does not stop the pass; neither do +:skipped+ or +:error+.
  # Unexpected errors from a source propagate (consistent with DataSource#call's
  # fail-loud contract); only an adapter's declared expected errors become
  # +:error+ results, which the base class handles.
  class DataSourceOrchestrator
    class << self
      # @param certification [Certification]
      # @return [Verification::OrchestrationResult]
      def evaluate(certification)
        new.evaluate(certification)
      end
    end

    def evaluate(certification)
      attempted = []

      ordered_sources.each do |entry|
        result = build_source(entry).call(certification: certification)
        attempted << { source_id: entry[:id], result: result }

        if positive?(result)
          return OrchestrationResult.new(
            satisfied: true,
            source_id: entry[:id],
            result: result,
            attempted: attempted
          )
        end
      end

      OrchestrationResult.new(satisfied: false, attempted: attempted)
    end

    private

    def ordered_sources
      Rails.application.config.verification_data_sources
        .select { |entry| entry[:enabled] && !entry[:order].nil? }
        .sort_by { |entry| entry[:order] }
    end

    def build_source(entry)
      entry[:adapter_class].constantize.new
    end

    def positive?(result)
      result.success? && result.outcomes.present?
    end
  end
end
