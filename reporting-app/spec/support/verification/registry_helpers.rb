# frozen_string_literal: true

# Stubs Rails.application.config.verification_data_sources, the booted data source registry.
# Extracted from identical defs previously repeated in data_source_orchestrator_spec and
# data_source_check_service_spec.
module VerificationRegistryHelpers
  def stub_registry(entries)
    allow(Rails.application.config).to receive(:verification_data_sources).and_return(entries)
  end

  def registry_entry(id:, adapter_class:, order: 10, enabled: true)
    { id: id, enabled: enabled, adapter_class: adapter_class, order: order }
  end
end

RSpec.configure do |config|
  config.include VerificationRegistryHelpers
end
