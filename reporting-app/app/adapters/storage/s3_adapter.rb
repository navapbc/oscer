# frozen_string_literal: true

require "aws-sdk-s3"

module Storage
  # AWS S3 implementation of the storage adapter interface
  class S3Adapter < BaseAdapter
    def initialize(client: nil, bucket: nil, region: nil)
      @bucket = bucket || ENV.fetch("STORAGE_BUCKET", ENV["BUCKET_NAME"])
      @region = region || ENV.fetch("STORAGE_REGION", "us-east-1")
      @client = client || Aws::S3::Client.new(region: @region)
    end

    # Upload an object to S3
    # @param key [String] The object key (path) in the bucket
    # @param body [String, IO] The object content
    # @param options [Hash] Additional options (content_type, metadata, etc.)
    # @return [Hash] Response from S3 containing etag, version_id, etc.
    def put_object(key:, body:, **options)
      @client.put_object(
        bucket: @bucket,
        key: key,
        body: body,
        **options
      )
    end

    # Download an object from S3
    # @param key [String] The object key (path) in the bucket
    # @return [String] The object content
    def get_object(key:)
      response = @client.get_object(
        bucket: @bucket,
        key: key
      )
      response.body.read
    end

    # Delete an object from S3
    # @param key [String] The object key (path) in the bucket
    # @return [Hash] Response from S3
    def delete_object(key:)
      @client.delete_object(
        bucket: @bucket,
        key: key
      )
    end

    # Check if an object exists in S3
    # @param key [String] The object key (path) in the bucket
    # @return [Boolean] true if object exists, false otherwise
    def object_exists?(key:)
      @client.head_object(
        bucket: @bucket,
        key: key
      )
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    # Get object metadata without downloading the full object
    # @param key [String] The object key (path) in the bucket
    # @return [Hash] Metadata including size, content_type, last_modified, etag
    def get_object_metadata(key:)
      response = @client.head_object(
        bucket: @bucket,
        key: key
      )
      {
        size: response.content_length,
        content_type: response.content_type,
        last_modified: response.last_modified,
        etag: response.etag,
        metadata: response.metadata
      }
    end

    # Generate a presigned URL for uploading an object to S3
    # @param key [String] The object key (path) in the bucket
    # @param content_type [String] MIME type of the object
    # @param expires_in [Integer] URL expiration time in seconds
    # @return [Hash] { url: String, key: String }
    def generate_signed_upload_url(key:, content_type:, expires_in:)
      presigner = Aws::S3::Presigner.new(client: @client)
      url = presigner.presigned_url(
        :put_object,
        bucket: @bucket,
        key: key,
        expires_in: expires_in,
        content_type: content_type
      )
      { url: url, key: key }
    end

    # Stream an object from S3 line by line
    # @param key [String] The object key (path) in the bucket
    # @yield [line] Yields each line from the file
    # @return [void]
    def stream_object(key:, &block)
      response = @client.get_object(bucket: @bucket, key: key)
      response.body.each_line(&block)
    end
  end
end
