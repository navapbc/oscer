# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for automated CE determinations with
  # {Determination::CALCULATION_TYPE_INCOME_BASED}. Built from
  # {IncomeComplianceDeterminationService.aggregate_income_for_certification} output.
  class IncomeBasedDeterminationData < ValueObject
    attribute :total_income
    attribute :income_by_source, default: -> { {} }
    attribute :period_start
    attribute :period_end
    attribute :income_ids, default: -> { [] }
    attribute :calculated_at, :string
    attribute :compliant, :boolean

    validates :calculated_at, presence: true
    validates :total_income, presence: true, numericality: true
    validate :income_by_source_is_hash

    # @param income_data [Hash] +:total_income+, +:income_by_source+ (+:income+, +:activity+),
    #   +:period_start+, +:period_end+, +:income_ids+
    # @param compliant [Boolean, nil] omit for income-only CE; set for combined nested +income+
    # @return [self]
    def self.from_aggregate(income_data, compliant: nil)
      new(
        total_income: income_data[:total_income],
        income_by_source: income_data[:income_by_source] || {},
        period_start: income_data[:period_start],
        period_end: income_data[:period_end],
        income_ids: Array(income_data[:income_ids]),
        calculated_at: Time.current.iso8601,
        compliant: compliant
      ).tap(&:validate!)
    end

    # @return [Hash{String => Object}] JSONB-safe keys and values for +Determination#determination_data+
    def to_h
      income_by = income_by_source || {}
      {
        "calculation_type" => Determination::CALCULATION_TYPE_INCOME_BASED,
        "total_income" => total_income.to_f,
        "target_income" => IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_f,
        "income_by_source" => {
          "income" => (income_by[:income] || income_by["income"]).to_f,
          "activity" => (income_by[:activity] || income_by["activity"]).to_f
        },
        "period_start" => serialize_period(period_start),
        "period_end" => serialize_period(period_end),
        "income_ids" => income_ids.map(&:to_s),
        "calculation_method" => Determination::CALCULATION_METHOD_AUTOMATED_INCOME_INTAKE,
        "calculated_at" => calculated_at
      }.tap do |h|
        h["compliant"] = compliant unless compliant.nil?
      end
    end

    private

    def income_by_source_is_hash
      errors.add(:income_by_source, :invalid) unless income_by_source.is_a?(Hash)
    end

    def serialize_period(value)
      return nil if value.nil?

      value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
    end
  end
end
