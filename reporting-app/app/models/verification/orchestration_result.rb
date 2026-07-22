# frozen_string_literal: true

module Verification
  # Result of one orchestration pass over the ordered non-exclusion data sources
  # (see {Verification::DataSourceOrchestrator}).
  #
  # It carries enough for a caller to both make a determination and audit the
  # pass: whether a source produced a positive result (+satisfied+), the winning
  # +source_id+ and its full {DataSourceResult} (which includes +outcomes+ and
  # redacted +audit_data+), and +attempted+ — the ordered list of every source
  # called, each as +{ source_id:, result: }+ — so skipped/errored sources are
  # never silently dropped.
  #
  # Value object in the style of {DataSourceResult}.
  class OrchestrationResult < ValueObject
    attribute :satisfied, default: false
    attribute :source_id
    attribute :result
    attribute :attempted, default: -> { [] }

    def satisfied?
      satisfied
    end
  end
end
