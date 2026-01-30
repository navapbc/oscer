# frozen_string_literal: true

module Storage
  # Base adapter defining the interface for cloud storage implementations.
  # All storage adapters must implement these methods.
  class BaseAdapter
    def initialize(**options)
      # Subclasses define their own initialization parameters
    end

    # Delete an object from storage
    # @param key [String] The object key (path) in the bucket
    def delete_object(key:)
      raise NotImplementedError
    end

    # Check if an object exists in storage
    # @param key [String] The object key (path) in the bucket
    def object_exists?(key:)
      raise NotImplementedError
    end

    # Generate a presigned URL for uploading an object
    # @param key [String] The object key (path) in the bucket
    # @param content_type [String] MIME type of the object
    # @param expires_in [Integer] URL expiration time in seconds
    def generate_signed_upload_url(key:, content_type:, expires_in:)
      raise NotImplementedError
    end

    # Stream an object from storage line by line with constant memory usage
    # Suitable for text files (CSV, logs, etc.). Streams data without loading
    # the entire file into memory, making it suitable for large files.
    # @param key [String] The object key (path) in the bucket
    def stream_object(key:, &block)
      raise NotImplementedError
    end
  end
end
