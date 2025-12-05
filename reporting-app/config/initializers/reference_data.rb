# frozen_string_literal: true

# Eagerly load reference data at application boot time
# This ensures YAML files are only loaded once during initialization
# Wrapped in after_initialize to ensure models are loaded first

Rails.application.config.after_initialize do
  Region.all
end
