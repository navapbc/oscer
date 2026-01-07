# frozen_string_literal: true

# Load exemption screener configuration after Rails initialization
# This ensures the config is available after the asset pipeline is set up
Rails.application.config.after_initialize do
  config = ExemptionScreenerConfig.new
  Rails.application.config.exemption_screener_config = config

  # Define the enum on ExemptionApplicationForm now that config is loaded
  enum_hash = config.exemption_types.each_with_object({}) do |type, hash|
    hash[type.to_sym] = type
  end

  ExemptionApplicationForm.enum :exemption_type, enum_hash

  # Add validation for exemption_type after enum is defined
  ExemptionApplicationForm.validates :exemption_type,
    inclusion: { in: ExemptionApplicationForm.exemption_types.values },
    allow_nil: true
end
