# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/ce_configuration")

base_path = Rails.root.join("config/ce_config_base.yml")
custom_path = Rails.root.join("config/ce_config.yml")

Rails.application.config.ce_data = CEConfiguration.load_and_merge(base_path, custom_path)
Rails.application.config.exemption_types = CEConfiguration.transform_exemption_types(
  Rails.application.config.ce_data
)
