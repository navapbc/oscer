# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/exemption_types_loader")

override_path = Rails.root.join("config/custom/exemption_types.yml")
overrides     = ExemptionTypesLoader.safe_load_optional(override_path)
merged        = ExemptionTypesLoader.merge_with_defaults(overrides)

Rails.application.config.exemption_types = ExemptionTypesLoader.transform(merged)
