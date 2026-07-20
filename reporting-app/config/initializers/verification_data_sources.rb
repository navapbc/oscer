# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/verification_data_sources_loader")

override_path = Rails.root.join("config/custom/verification_data_sources.yml")
overrides     = VerificationDataSourcesLoader.safe_load_optional(override_path)
merged        = VerificationDataSourcesLoader.merge_with_defaults(overrides)

# Structural validation runs in the body; the config holds each entry's
# adapter_class as a String. Outcomes live on the adapter via .declared_outcomes
# (constantized/validated below, once autoloading is ready).
Rails.application.config.verification_data_sources = VerificationDataSourcesLoader.transform(merged)

# Registry validation depends on application constants (adapter classes plus the
# Exclusion / ExternalException registries populated by sibling initializers), so
# defer it to a to_prepare hook rather than running it in the initializer body
# where autoloading app code is unsafe.
Rails.application.config.to_prepare do
  VerificationDataSourcesLoader.validate_registry!(Rails.application.config.verification_data_sources)
end
