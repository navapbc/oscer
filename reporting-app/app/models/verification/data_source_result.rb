# frozen_string_literal: true

module Verification
  # Uniform result returned by every {Verification::DataSource}.
  #
  # A result carries the outcome of calling one external verification data
  # source for a certification: a +status+, the +outcomes+ (symbols) the
  # source emitted, and redacted +audit_data+ for later inspection. It is a
  # value object in the style of +Determinations::*DeterminationData+.
  #
  # Construct only via the factories ({.skipped}, {.success}, {.error}) — they
  # normalize inputs and enforce the contract invariants:
  #
  #   * +status+ is always one of {STATUSES}
  #   * +outcomes+ is always a flat +Array<Symbol>+ (empty allowed; empty on
  #     +:success+ means "called, no matching outcome")
  #   * +audit_data+ is always a +Hash+ (never +nil+; may be +{}+)
  #   * +error_code+/+error_message+ accompany +:error+
  #
  # +audit_data+ must be redacted by the adapter before it reaches here: no
  # raw PHI, secrets, or tokens.
  class DataSourceResult < ValueObject
    STATUS_SKIPPED = :skipped
    STATUS_SUCCESS = :success
    STATUS_ERROR = :error
    STATUSES = [ STATUS_SKIPPED, STATUS_SUCCESS, STATUS_ERROR ].freeze

    attribute :status
    attribute :outcomes, default: -> { [] }
    attribute :audit_data, default: -> { {} }
    attribute :error_code
    attribute :error_message

    validates :status, inclusion: { in: STATUSES }
    validate :outcomes_is_symbol_array
    validate :audit_data_is_hash

    class << self
      # A precondition was missing (e.g. no ICN), so the source was not
      # called. Distinct from a +:success+ with empty outcomes.
      #
      # @param reason [Symbol, String, nil] optional machine-readable skip
      #   reason, recorded under +audit_data[:skip_reason]+.
      # @param audit_data [Hash] optional additional audit context.
      # @return [DataSourceResult]
      def skipped(reason: nil, audit_data: {})
        audit = normalize_audit_data(audit_data)
        audit = audit.merge(skip_reason: reason) unless reason.nil?

        build(status: STATUS_SKIPPED, audit_data: audit)
      end

      # The source was called and returned successfully. +outcomes+ may be
      # empty, which means "called, no matching outcome".
      #
      # @param outcomes [Array<Symbol>] emitted outcomes (may be empty).
      # @param audit_data [Hash] redacted audit context (required — every
      #   non-skipped call records audit data).
      # @return [DataSourceResult]
      def success(audit_data:, outcomes: [])
        build(status: STATUS_SUCCESS, outcomes: outcomes, audit_data: audit_data)
      end

      # The source was called but failed for an expected integration reason
      # (auth, 5xx, timeout, rate limit). Adapters never raise for these.
      #
      # @param error_code [Symbol, String] machine-readable error category.
      # @param error_message [String] human-readable, redacted message.
      # @param audit_data [Hash] redacted audit context (required).
      # @param outcomes [Array<Symbol>] usually empty on error.
      # @return [DataSourceResult]
      def error(error_code:, error_message:, audit_data:, outcomes: [])
        build(
          status: STATUS_ERROR,
          outcomes: outcomes,
          audit_data: audit_data,
          error_code: error_code,
          error_message: error_message
        )
      end

      private

      def build(status:, audit_data:, outcomes: [], error_code: nil, error_message: nil)
        new(
          status: status,
          outcomes: normalize_outcomes(outcomes),
          audit_data: normalize_audit_data(audit_data),
          error_code: error_code,
          error_message: error_message
        ).tap(&:validate!)
      end

      def normalize_outcomes(outcomes)
        Array(outcomes).freeze
      end

      # Deep-copies, then deep-freezes, so the persisted audit record is
      # tamper-resistant all the way down. The +deep_dup+ ensures we freeze our
      # own copy rather than mutating the caller's hash (and its nested objects)
      # in place.
      def normalize_audit_data(audit_data)
        deep_freeze((audit_data || {}).to_h.deep_dup)
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each_value { |v| deep_freeze(v) }
        when Array
          value.each { |v| deep_freeze(v) }
        end
        value.freeze
      end
    end

    def skipped?
      status == STATUS_SKIPPED
    end

    def success?
      status == STATUS_SUCCESS
    end

    def error?
      status == STATUS_ERROR
    end

    private

    def outcomes_is_symbol_array
      unless outcomes.is_a?(Array) && outcomes.all?(Symbol)
        errors.add(:outcomes, "must be a flat Array of Symbols")
      end
    end

    def audit_data_is_hash
      errors.add(:audit_data, "must be a Hash") unless audit_data.is_a?(Hash)
    end
  end
end
