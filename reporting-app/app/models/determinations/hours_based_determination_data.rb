# frozen_string_literal: true

module Determinations
  # Canonical serialized shape for automated CE determinations with
  # {Determination::CALCULATION_TYPE_HOURS_BASED}. Built from
  # {HoursComplianceDeterminationService.aggregate_hours_for_certification} output.
  class HoursBasedDeterminationData < ValueObject
    attribute :total_hours
    attribute :hours_by_category, default: -> { {} }
    attribute :hours_by_source, default: -> { {} }
    attribute :ex_parte_activity_ids, default: -> { [] }
    attribute :activity_ids, default: -> { [] }
    attribute :calculated_at, :string
    # When set (ex parte combined CE nested +hours+ payload), included in {#to_h}.
    attribute :compliant, :boolean

    validates :calculated_at, presence: true
    validates :total_hours, presence: true, numericality: true
    validate :hours_by_category_is_hash
    validate :hours_by_source_is_hash

    # @param hours_data [Hash] +:total_hours+, +:hours_by_category+, +:hours_by_source+,
    #   +:ex_parte_activity_ids+, +:activity_ids+ (see aggregate service)
    # @param compliant [Boolean, nil] omit for standalone hours CE; set for combined nested +hours+
    # @return [self]
    def self.from_aggregate(hours_data, compliant: nil)
      new(
        total_hours: hours_data[:total_hours],
        hours_by_category: hours_data[:hours_by_category] || {},
        hours_by_source: hours_data[:hours_by_source] || {},
        ex_parte_activity_ids: Array(hours_data[:ex_parte_activity_ids]),
        activity_ids: Array(hours_data[:activity_ids]),
        calculated_at: Time.current.iso8601,
        compliant: compliant
      ).tap(&:validate!)
    end

    # @return [Hash{String => Object}] JSONB-safe keys and values for +Determination#determination_data+
    def to_h
      by_source = (hours_by_source || {}).stringify_keys.transform_values { |v| v.to_f }
      {
        "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED,
        "total_hours" => total_hours.to_f,
        "target_hours" => HoursComplianceDeterminationService::TARGET_HOURS,
        "hours_by_category" => (hours_by_category || {}).stringify_keys.transform_values { |v| v.to_f },
        "hours_by_source" => by_source,
        "ex_parte_activity_ids" => ex_parte_activity_ids.map(&:to_s),
        "activity_ids" => activity_ids.map(&:to_s),
        "calculated_at" => calculated_at
      }.tap do |h|
        h["compliant"] = compliant unless compliant.nil?
      end
    end

    private

    def hours_by_category_is_hash
      errors.add(:hours_by_category, :invalid) unless hours_by_category.is_a?(Hash)
    end

    def hours_by_source_is_hash
      errors.add(:hours_by_source, :invalid) unless hours_by_source.is_a?(Hash)
    end
  end
end
