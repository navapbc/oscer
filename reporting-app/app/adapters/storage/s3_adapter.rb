# frozen_string_literal: true

require "aws-sdk-s3"

module Storage
  # AWS S3 implementation of the storage adapter interface
  class S3Adapter < BaseAdapter
    def initialize(client: nil, bucket: nil, region: nil)
      @bucket = bucket || ENV.fetch("BUCKET_NAME")
      @region = region || ENV.fetch("AWS_REGION", "us-east-1")
      @client = client || Aws::S3::Client.new(region: @region)
    end

    # Delete an object from S3
    # @param key [String] The object key (path) in the bucket
    def delete_object(key:)
      @client.delete_object(
        bucket: @bucket,
        key: key
      )
    end

    # Check if an object exists in S3
    # @param key [String] The object key (path) in the bucket
    def object_exists?(key:)
      @client.head_object(
        bucket: @bucket,
        key: key
      )
      true
    rescue Aws::S3::Errors::NotFound
      # Note: head_object returns NotFound (not NoSuchKey) because HTTP HEAD
      # responses have no body. AWS SDK creates the error class dynamically from
      # the HTTP 404 status code without a specific error code from the response body.
      false
    end

    # Generate a presigned URL for uploading an object to S3
    # @param key [String] The object key (path) in the bucket
    # @param content_type [String] MIME type of the object
    # @param expires_in [Integer] URL expiration time in seconds
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
    # Uses AWS SDK's block-based streaming to read chunks from the socket,
    # buffering until complete lines are found. Constant memory usage.
    # @param key [String] The object key (path) in the bucket
    def stream_object(key:, &block)
      line_buffer = +""

      @client.get_object(bucket: @bucket, key: key) do |chunk|
        line_buffer << chunk

        while (newline_idx = line_buffer.index("\n"))
          line = line_buffer.slice!(0..newline_idx)
          yield line
        end
      end

      # Yield remaining content (file without trailing newline)
      yield line_buffer unless line_buffer.empty?
    end
  end
end
