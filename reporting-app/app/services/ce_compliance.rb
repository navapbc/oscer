# frozen_string_literal: true

# CE compliance configuration.
# Reads and validates CE_INCOME_THRESHOLD_MONTHLY at boot (via config initializer).
module CECompliance
  def self.fetch_income_threshold
    value = BigDecimal(ENV.fetch("CE_INCOME_THRESHOLD_MONTHLY", "580"))
    unless value.positive?
      raise ArgumentError,
            "CE_INCOME_THRESHOLD_MONTHLY must be positive, got #{value.inspect}"
    end
    value.freeze
  end
end
