# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for the combined hours + income external CE step
  # (+Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED+): one automated determination with nested hours and
  # income assessment payloads.
  #
  # Use only {.build} to construct instances: it runs eager nested validation and memoizes nested VOs.
  # Calling {#to_h} without {.build} is unsupported and raises.
  #
  # Nested {HoursBasedDeterminationData} and {IncomeBasedDeterminationData} are validated during
  # {.build} (eager), not only when {#to_h} serializes, so invalid inner aggregates raise before persist.
  #
  # The combined-hours track is the last resort {CommunityEngagementCheckService} reaches for when
  # neither of the other two passes, so its aggregate is absent from most payloads and its nested
  # +combined_hours+ hash is omitted when it is. It is carried beside the reported-hours aggregate
  # rather than replacing it, so a reviewer can tell imputed hours from reported ones.
  class ExternalCECombinedDeterminationData < ValueObject
    attribute :hours_data
    attribute :income_data
    attribute :combined_hours_data
    attribute :hours_ok, :boolean
    attribute :income_ok, :boolean
    attribute :combined_hours_ok, :boolean
    attribute :calculated_at, :string

    validates :calculated_at, presence: true
    validates :hours_ok, inclusion: { in: [ true, false ] }
    validates :income_ok, inclusion: { in: [ true, false ] }
    validates :combined_hours_ok, inclusion: { in: [ true, false ] }, allow_nil: true
    validate :hours_data_is_hash
    validate :income_data_is_hash
    validate :combined_hours_data_is_hash_when_present
    validate :combined_hours_track_is_all_or_nothing

    # @param hours_data [Hash] aggregate from {HoursComplianceDeterminationService.aggregate_hours_for_certification}
    # @param income_data [Hash] aggregate from {IncomeComplianceDeterminationService.aggregate_income_for_certification}
    # @param combined_hours_data [Hash, nil] the same hours aggregate recomputed with earned income
    #   imputed as hours; nil unless the fallback was consulted
    # @param combined_hours_ok [Boolean, nil] goes with +combined_hours_data+; either alone is a
    #   validation error
    # @return [self]
    # @raise [ActiveModel::ValidationError] outer or nested aggregate payload is invalid
    def self.build(hours_data:, income_data:, hours_ok:, income_ok:,
                   combined_hours_data: nil, combined_hours_ok: nil)
      new(
        hours_data: indifferent(hours_data),
        income_data: indifferent(income_data),
        combined_hours_data: combined_hours_data.nil? ? nil : indifferent(combined_hours_data),
        hours_ok: hours_ok,
        income_ok: income_ok,
        combined_hours_ok: combined_hours_ok,
        calculated_at: Time.current.iso8601
      ).tap do |vo|
        vo.validate!
        vo.send(:validate_nested_aggregate_payloads!)
      end
    end

    def self.indifferent(payload)
      payload.is_a?(Hash) ? payload.to_h.with_indifferent_access : payload
    end
    private_class_method :indifferent

    # @return [Hash{String => Object}] JSONB-safe keys and values for +Determination#determination_data+
    # @raise [ArgumentError] if nested VOs were not populated via {.build} (e.g. +#to_h+ on an instance constructed with +new+). Invalid aggregates instead raise {ActiveModel::ValidationError} during {.build}.
    def to_h
      {
        "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
        "satisfied_by" => satisfied_by,
        "hours" => nested_hours_hash,
        "income" => nested_income_hash,
        "calculated_at" => calculated_at
      }.tap do |h|
        h["combined_hours"] = nested_combined_hours_vo.to_h if combined_hours_data.present?
      end
    end

    private

    def validate_nested_aggregate_payloads!
      @nested_hours_vo = HoursBasedDeterminationData.from_aggregate(hours_data, compliant: hours_ok)
      @nested_income_vo = IncomeBasedDeterminationData.from_aggregate(income_data, compliant: income_ok)
      return if combined_hours_data.blank?

      @nested_combined_hours_vo = HoursBasedDeterminationData.from_aggregate(
        combined_hours_data, compliant: combined_hours_ok
      )
    end

    # The combined track is only consulted once the other two have failed, so it never competes.
    def satisfied_by
      if hours_ok && income_ok
        Determination::SATISFIED_BY_BOTH
      elsif hours_ok
        Determination::SATISFIED_BY_HOURS
      elsif income_ok
        Determination::SATISFIED_BY_INCOME
      elsif combined_hours_ok
        Determination::SATISFIED_BY_COMBINED_HOURS
      else
        Determination::SATISFIED_BY_NEITHER
      end
    end

    def nested_hours_hash
      nested_hours_vo.to_h
    end

    def nested_income_hash
      nested_income_vo.to_h
    end

    def nested_hours_vo
      raise ArgumentError, "call #{self.class.name}.build(...) before #to_h" if @nested_hours_vo.nil?

      @nested_hours_vo
    end

    def nested_income_vo
      raise ArgumentError, "call #{self.class.name}.build(...) before #to_h" if @nested_income_vo.nil?

      @nested_income_vo
    end

    def nested_combined_hours_vo
      raise ArgumentError, "call #{self.class.name}.build(...) before #to_h" if @nested_combined_hours_vo.nil?

      @nested_combined_hours_vo
    end

    def hours_data_is_hash
      errors.add(:hours_data, :invalid) unless hours_data.is_a?(Hash)
    end

    def income_data_is_hash
      errors.add(:income_data, :invalid) unless income_data.is_a?(Hash)
    end

    def combined_hours_data_is_hash_when_present
      return if combined_hours_data.nil? || combined_hours_data.is_a?(Hash)

      errors.add(:combined_hours_data, :invalid)
    end

    # The fallback was either consulted or it was not: a verdict with no aggregate would put a
    # compliant determination on an empty payload, an aggregate with no verdict would serialize
    # figures nothing weighed.
    def combined_hours_track_is_all_or_nothing
      return if combined_hours_data.nil? == combined_hours_ok.nil?

      errors.add(:combined_hours_ok, :invalid)
    end
  end
end
