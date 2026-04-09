# frozen_string_literal: true

# Single source for the monthly income threshold used in CE compliance UI and statistics
# (parity with HoursComplianceDeterminationService::TARGET_HOURS).
class IncomeComplianceDeterminationService
  TARGET_INCOME_MONTHLY = Rails.application.config.ce_compliance[:income_threshold_monthly]
end
