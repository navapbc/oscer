# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for the combined hours + income CE step
  # (+Determination::CALCULATION_TYPE_CE_COMBINED+): one automated determination with nested hours and
  # income assessment payloads.
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
    def self.build(hours_data:, income_data:, hours_ok:, income_ok:)
      new(
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: hours_ok,
        income_ok: income_ok,
        calculated_at: Time.current.iso8601
      ).tap(&:validate!)
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
      HoursBasedDeterminationData.from_aggregate(hours_data, compliant: hours_ok).to_h
    end

    def nested_income_hash
      IncomeBasedDeterminationData.from_aggregate(income_data, compliant: income_ok).to_h
    end

    def hours_data_is_hash
      errors.add(:hours_data, :invalid) unless hours_data.is_a?(Hash)
    end

    def income_data_is_hash
      errors.add(:income_data, :invalid) unless income_data.is_a?(Hash)
    end
  end
end
