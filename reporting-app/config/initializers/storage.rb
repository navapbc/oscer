# frozen_string_literal: true

# Configuration for custom storage adapters used in batch upload v2
# This is separate from Active Storage (config/storage.yml)
#
# Set STORAGE_ADAPTER environment variable to select provider:
#   - s3 (default): AWS S3
#   - azure: Azure Blob Storage
#   - gcp: Google Cloud Storage
#
# Example configurations:
#
# AWS S3 (default):
#   STORAGE_ADAPTER=s3
#   BUCKET_NAME=my-bucket
#   AWS_REGION=us-east-1
#
# Azure Blob Storage:
#   STORAGE_ADAPTER=azure
#   AZURE_STORAGE_ACCOUNT=myaccount
#   AZURE_CONTAINER_NAME=batch-uploads
#
# Google Cloud Storage:
#   STORAGE_ADAPTER=gcp
#   GCS_BUCKET=my-bucket
#   GCS_PROJECT_ID=my-project

module StorageConfig
  S3 = "s3"
  AZURE = "azure"
  GCP = "gcp"

  VALID_ADAPTERS = [ S3, AZURE, GCP ].freeze
  DEFAULT_ADAPTER = S3
end

Rails.application.config.to_prepare do
  # Skip if already initialized (to_prepare runs before each request in development)
  next if Rails.application.config.respond_to?(:storage_adapter)

  # Skip initialization in test environment (tests use mocks/stubs)
  next if Rails.env.test?

  # Skip if required environment variables aren't present (e.g., during asset precompilation)
  next unless ENV["BUCKET_NAME"].present?

  adapter_type = ENV.fetch("STORAGE_ADAPTER", StorageConfig::DEFAULT_ADAPTER).downcase

  Rails.application.config.storage_adapter = case adapter_type
  when StorageConfig::S3
    Storage::S3Adapter.new
  when StorageConfig::AZURE
    raise NotImplementedError, "Azure adapter not yet implemented (see issue #212)"
  when StorageConfig::GCP
    raise NotImplementedError, "GCP adapter not yet implemented"
  else
    raise ArgumentError, "Unknown STORAGE_ADAPTER: #{adapter_type}. " \
                         "Valid options: #{StorageConfig::VALID_ADAPTERS.join(', ')}"
  end
end
