# frozen_string_literal: true

# Stubs Rails.application.config.verification_data_sources, the booted data source registry.
# Extracted from data_source_orchestrator_spec so any spec exercising the pass can stub the
# registry the same way.
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
