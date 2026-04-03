# frozen_string_literal: true

# Single source for the monthly income threshold used in CE compliance UI and statistics
# (parity with HoursComplianceDeterminationService::TARGET_HOURS).
class IncomeComplianceDeterminationService
  TARGET_INCOME_MONTHLY = BigDecimal(ENV.fetch("CE_INCOME_THRESHOLD_MONTHLY", "580")).freeze

  unless TARGET_INCOME_MONTHLY.positive?
    raise ArgumentError,
          "CE_INCOME_THRESHOLD_MONTHLY must be positive, got #{TARGET_INCOME_MONTHLY.inspect}"
  end
end
