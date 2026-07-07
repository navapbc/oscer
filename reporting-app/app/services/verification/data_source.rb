# frozen_string_literal: true

module Verification
  # Contract every external verification data source conforms to.
  #
  # A data source is called with the full {Certification}; it pulls whatever it
  # needs (e.g. +certification.member_data&.va_icn+), calls its backing
  # integration, and returns a {DataSourceResult} with a uniform shape so an
  # orchestrator (built later, out of scope here) can call every source
  # identically and audit them consistently.
  #
  # Subclasses implement the protected hooks — {#precondition_met?} and
  # {#perform} — plus the class method {.declared_outcomes}. The public
  # {#call} is a template method that enforces the contract *by design*:
  #
  #   * never returns +nil+ (a non-{DataSourceResult} return raises {ContractError})
  #   * never raises for *expected* integration failures — error classes listed
  #     in {#expected_error_classes} are caught and become +status: :error+
  #   * returns +:skipped+ when a precondition is missing, distinct from a
  #     +:success+ with empty outcomes
  #
  # Unexpected errors (bugs, undeclared exceptions) intentionally propagate so
  # they surface loudly rather than being silently swallowed.
  class DataSource
    # Raised when a subclass's {#perform} violates the contract by returning
    # something other than a {DataSourceResult}.
    class ContractError < StandardError; end

    class << self
      # The full set of outcome symbols this source may emit. Config (ticket C)
      # validates configured outcomes against this list.
      #
      # @return [Array<Symbol>]
      def declared_outcomes
        raise NotImplementedError, "#{name} must implement .declared_outcomes"
      end
    end

    # Uniform entry point.
    #
    # @param certification [Certification]
    # @return [DataSourceResult]
    def call(certification:)
      return skipped_result unless precondition_met?(certification)

      ensure_result!(perform(certification: certification))
    rescue *expected_error_classes => e
      error_result(e)
    end

    protected

    # Whether the source has what it needs to run (e.g. an ICN is present).
    # When this is false, {#call} short-circuits to a +:skipped+ result.
    #
    # @param certification [Certification]
    # @return [Boolean]
    def precondition_met?(_certification)
      raise NotImplementedError, "#{self.class.name} must implement #precondition_met?"
    end

    # Perform the verification and return a {DataSourceResult}. Called only
    # when {#precondition_met?} is true. Expected integration failures should
    # be raised as one of {#expected_error_classes} (caught by {#call}) rather
    # than rescued here.
    #
    # @param certification [Certification]
    # @return [DataSourceResult]
    def perform(certification:)
      raise NotImplementedError, "#{self.class.name} must implement #perform"
    end

    # Error classes representing *expected* integration failures (auth, 5xx,
    # timeout, rate limit). {#call} catches these and returns a +:error+ result.
    #
    # @return [Array<Class>]
    def expected_error_classes
      []
    end

    # Build a +:skipped+ result. Subclasses may pass a machine-readable reason.
    def skipped_result(reason: nil, audit_data: {})
      DataSourceResult.skipped(reason: reason, audit_data: audit_data)
    end

    # Build a +:success+ result.
    def success_result(audit_data:, outcomes: [])
      DataSourceResult.success(outcomes: outcomes, audit_data: audit_data)
    end

    # Build a +:error+ result from a caught expected error. Subclasses can pass
    # redacted +audit_data+; the error's class and message are recorded.
    def error_result(error, audit_data: {})
      DataSourceResult.error(
        error_code: error_code_for(error),
        error_message: error.message,
        audit_data: audit_data
      )
    end

    def error_code_for(error)
      error.class.name.demodulize.underscore.to_sym
    end

    private

    def ensure_result!(result)
      return result if result.is_a?(DataSourceResult)

      raise ContractError,
        "#{self.class.name}#perform must return a Verification::DataSourceResult, got #{result.inspect}"
    end
  end
end
