# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for the combined hours + income CE step
  # (+Determination::CALCULATION_TYPE_CE_COMBINED+): one automated determination with nested hours and
  # income assessment payloads.
  #
  # Nested {HoursBasedDeterminationData} and {IncomeBasedDeterminationData} are validated during
  # {.build} (eager), not only when {#to_h} serializes, so invalid inner aggregates raise before persist.
  # After {.build}, nested instances are memoized so {#to_h} does not reconstruct them.
  class CECombinedDeterminationData < ValueObject
    attribute :hours_data
    attribute :income_data
    attribute :hours_ok, :boolean
    attribute :income_ok, :boolean
    attribute :calculated_at, :string

    validates :calculated_at, presence: true
    validates :hours_ok, inclusion: { in: [ true, false ] }
    validates :income_ok, inclusion: { in: [ true, false ] }
    validate :hours_data_is_hash
    validate :income_data_is_hash

    # @param hours_data [Hash] aggregate from {HoursComplianceDeterminationService.aggregate_hours_for_certification}
    # @param income_data [Hash] aggregate from {IncomeComplianceDeterminationService.aggregate_income_for_certification}
    # @return [self]
    # @raise [ActiveModel::ValidationError] outer or nested aggregate payload is invalid
    def self.build(hours_data:, income_data:, hours_ok:, income_ok:)
      new(
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: hours_ok,
        income_ok: income_ok,
        calculated_at: Time.current.iso8601
      ).tap do |vo|
        vo.validate!
        vo.send(:validate_nested_aggregate_payloads!)
      end
    end

    # @return [Hash{String => Object}] JSONB-safe keys and values for +Determination#determination_data+
    def to_h
      {
        "calculation_type" => Determination::CALCULATION_TYPE_CE_COMBINED,
        "satisfied_by" => satisfied_by,
        "hours" => nested_hours_hash,
        "income" => nested_income_hash,
        "calculated_at" => calculated_at
      }
    end

    private

    def validate_nested_aggregate_payloads!
      @nested_hours_vo = HoursBasedDeterminationData.from_aggregate(hours_data, compliant: hours_ok)
      @nested_income_vo = IncomeBasedDeterminationData.from_aggregate(income_data, compliant: income_ok)
    end

    def satisfied_by
      if hours_ok && income_ok
        Determination::SATISFIED_BY_BOTH
      elsif hours_ok
        Determination::SATISFIED_BY_HOURS
      elsif income_ok
        Determination::SATISFIED_BY_INCOME
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
      @nested_hours_vo ||= HoursBasedDeterminationData.from_aggregate(hours_data, compliant: hours_ok)
    end

    def nested_income_vo
      @nested_income_vo ||= IncomeBasedDeterminationData.from_aggregate(income_data, compliant: income_ok)
    end

    def hours_data_is_hash
      errors.add(:hours_data, :invalid) unless hours_data.is_a?(Hash)
    end

    def income_data_is_hash
      errors.add(:income_data, :invalid) unless income_data.is_a?(Hash)
    end
  end
end
