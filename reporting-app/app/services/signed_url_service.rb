# frozen_string_literal: true

class SignedUrlService
  DEFAULT_CONTENT_TYPE = "text/csv"
  DEFAULT_EXPIRY = 1.hour.to_i

  def initialize(storage_adapter: nil)
    @storage = storage_adapter || Rails.application.config.storage_adapter
  end

  # Generate a presigned URL for uploading a file directly to storage
  # @param filename [String] The original filename
  # @param content_type [String] MIME type of the file (default: text/csv)
  # @param expires_in [Integer] URL expiration time in seconds (default: 1 hour)
  # @return [Hash] { url: String, key: String }
  def generate_upload_url(filename:, content_type: DEFAULT_CONTENT_TYPE, expires_in: DEFAULT_EXPIRY)
    key = generate_storage_key(filename)

    @storage.generate_signed_upload_url(
      key: key,
      content_type: content_type,
      expires_in: expires_in
    )
  end

  private

  def generate_storage_key(filename)
    uuid = SecureRandom.uuid
    "batch-uploads/#{uuid}/#{filename}"
  end
end
