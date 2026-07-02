locals {
  # Legacy FF_* Parameter Store flags (see infra/reporting-app/service/feature_flags.tf).
  # OSCER app feature toggles read FEATURE_* env vars via the Features module
  # (config/initializers/feature_flags.rb) and are set per environment in each
  # env's service_override_extra_environment_variables (e.g. FEATURE_DOC_AI,
  # FEATURE_DEMO_CERTIFICATIONS) — not in this map.
  #
  # Map from feature flags to their default values (true or false)
  feature_flag_defaults = {
    # Example feature flags
    # FOO = false
    # BAR = false
  }
  feature_flags_config = merge(
    local.feature_flag_defaults,
    var.feature_flag_overrides
  )
}
