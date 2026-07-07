# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/exclusion_types_loader")

override_path = Rails.root.join("config/custom/exclusion_types.yml")
overrides     = ExclusionTypesLoader.safe_load_optional(override_path)
merged        = ExclusionTypesLoader.merge_with_defaults(overrides)

Rails.application.config.exclusion_types = ExclusionTypesLoader.transform(merged)
