# frozen_string_literal: true

module Storage
  # Base adapter defining the interface for cloud storage implementations.
  # All storage adapters must implement these methods.
  class BaseAdapter
    def initialize(client: nil, bucket: nil, region: nil)
      @client = client
      @bucket = bucket
      @region = region
    end

    # Upload an object to storage
    # @param key [String] The object key (path) in the bucket
    # @param body [String, IO] The object content
    # @param options [Hash] Additional options (content_type, metadata, etc.)
    # @return [Hash] Response containing etag, version_id, etc.
    def put_object(key:, body:, **options)
      raise NotImplementedError
    end

    # Download an object from storage
    # @param key [String] The object key (path) in the bucket
    # @return [String] The object content
    def get_object(key:)
      raise NotImplementedError
    end

    # Delete an object from storage
    # @param key [String] The object key (path) in the bucket
    # @return [Hash] Response from storage provider
    def delete_object(key:)
      raise NotImplementedError
    end

    # Check if an object exists in storage
    # @param key [String] The object key (path) in the bucket
    # @return [Boolean] true if object exists, false otherwise
    def object_exists?(key:)
      raise NotImplementedError
    end

    # Get object metadata without downloading the full object
    # @param key [String] The object key (path) in the bucket
    # @return [Hash] Metadata including size, content_type, last_modified, etag
    def get_object_metadata(key:)
      raise NotImplementedError
    end

    # Generate a presigned URL for uploading an object
    # @param key [String] The object key (path) in the bucket
    # @param content_type [String] MIME type of the object
    # @param expires_in [Integer] URL expiration time in seconds
    # @return [Hash] { url: String, key: String }
    def generate_signed_upload_url(key:, content_type:, expires_in:)
      raise NotImplementedError
    end

    # Stream an object from storage in chunks
    # @param key [String] The object key (path) in the bucket
    # @yield [chunk] Yields each chunk of data as it's read
    # @return [void]
    def stream_object(key:, &block)
      raise NotImplementedError
    end
  end
end
