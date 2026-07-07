# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/external_exceptions_loader")

override_path = Rails.root.join("config/custom/external_exceptions.yml")
overrides     = ExternalExceptionsLoader.safe_load_optional(override_path)
merged        = ExternalExceptionsLoader.merge_with_defaults(overrides)

Rails.application.config.external_exceptions = ExternalExceptionsLoader.transform(merged)
