# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/ce_compliance")

# Community engagement (CE) thresholds from ENV. See docs/infra/environment-variables-and-secrets.md.
Rails.application.config.ce_compliance = {
  income_threshold_monthly: CECompliance.fetch_income_threshold
}.freeze
