# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for automated CE determinations with
  # {Determination::CALCULATION_TYPE_INCOME_BASED}. Built from
  # {IncomeComplianceDeterminationService.aggregate_income_for_certification} output.
  #
  # +external_income_activity_ids+ kept its name across the external-activity consolidation, so ids
  # written before it point at +external_income_activities+ and later ones at +external_activities+.
  # They are audit breadcrumbs that nothing dereferences; the earlier ones dangle once the
  # superseded table is dropped.
  class IncomeBasedDeterminationData < ValueObject
    attribute :total_income
    attribute :maximum_monthly_income
    attribute :income_by_source, default: -> { {} }
    attribute :period_start
    attribute :period_end
    attribute :external_income_activity_ids, default: -> { [] }
    attribute :activity_ids, default: -> { [] }
    attribute :calculated_at, :string
    attribute :compliant, :boolean

    validates :calculated_at, presence: true
    validates :total_income, presence: true, numericality: true
    validates :maximum_monthly_income, numericality: true, allow_nil: true
    validate :income_by_source_is_hash
    validate :income_by_source_keys_allowed

    ALLOWED_INCOME_BY_SOURCE_KEYS = %w[external activity].freeze

    # @param income_data [Hash] +:total_income+, +:income_by_month+, +:income_by_source+ (only +:external+ and
    #   +:activity+ totals), +:period_start+, +:period_end+, +:external_income_activity_ids+, +:activity_ids+. Keys may be
    #   strings or symbols (+with_indifferent_access+ is applied internally). Unknown keys on +income_by_source+ fail validation.
    # @param compliant [Boolean, nil] omit for income-only CE; set for combined nested +income+
    # @return [self]
    def self.from_aggregate(income_data, compliant: nil)
      income_data = income_data.with_indifferent_access
      new(
        total_income: income_data[:total_income],
        maximum_monthly_income: best_month(income_data[:income_by_month]),
        income_by_source: income_data[:income_by_source] || {},
        period_start: income_data[:period_start],
        period_end: income_data[:period_end],
        external_income_activity_ids: Array(income_data[:external_income_activity_ids]),
        activity_ids: Array(income_data[:activity_ids]),
        calculated_at: Time.current.iso8601,
        compliant: compliant
      ).tap(&:validate!)
    end

    # Zero when the member reported no months; nil when the aggregate omits the map, so an
    # omission is never mistaken for a real zero.
    def self.best_month(income_by_month)
      return nil if income_by_month.nil?

      income_by_month.values.max || 0
    end
    private_class_method :best_month

    # @return [Hash{String => Object}] JSONB-safe keys and values for +Determination#determination_data+
    def to_h
      income_by = (income_by_source || {}).with_indifferent_access
      {
        "calculation_type" => Determination::CALCULATION_TYPE_INCOME_BASED,
        "total_income" => total_income.to_f,
        "maximum_monthly_income" => maximum_monthly_income&.to_f,
        "target_income" => IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_f,
        "income_by_source" => {
          "external" => income_by[:external].to_f,
          "activity" => income_by[:activity].to_f
        },
        "period_start" => serialize_period(period_start),
        "period_end" => serialize_period(period_end),
        "external_income_activity_ids" => external_income_activity_ids.map(&:to_s),
        "activity_ids" => activity_ids.map(&:to_s),
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

    def income_by_source_keys_allowed
      return unless income_by_source.is_a?(Hash)

      keys = income_by_source.keys.map(&:to_s)
      unknown = keys - ALLOWED_INCOME_BY_SOURCE_KEYS
      errors.add(:income_by_source, :invalid) if unknown.any?
    end

    def serialize_period(value)
      return nil if value.nil?

      value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
    end
  end
end
