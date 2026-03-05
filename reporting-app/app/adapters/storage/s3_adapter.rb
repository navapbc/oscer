# frozen_string_literal: true

require "aws-sdk-s3"

module Storage
  # AWS S3 streaming adapter for batch upload processing.
  # Active Storage handles uploads/deletes; this adapter handles efficient streaming.
  class S3Adapter < BaseAdapter
    def initialize(client: nil, bucket: nil, region: nil)
      @bucket = bucket || ENV.fetch("BUCKET_NAME")
      @region = region || ENV.fetch("AWS_REGION", "us-east-1")
      @client = client || Aws::S3::Client.new(region: @region)
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

    # Stream an object from S3 line by line
    # Uses AWS SDK's block-based streaming to read data from the socket,
    # buffering until complete lines are found. Constant memory usage.
    # @param key [String] The object key (path) in the bucket
    def stream_object(key:, &block)
      stream_lines(bucket: @bucket, key: key, &block)
    end

    # Stream a byte range from an S3 object, line by line
    # Uses HTTP Range header to read only the specified byte range,
    # then buffers and yields complete lines. Constant memory usage.
    # @param key [String] The object key (path) in the bucket
    # @param start_byte [Integer] Start of byte range (inclusive)
    # @param end_byte [Integer] End of byte range (inclusive)
    def stream_object_range(key:, start_byte:, end_byte:, &block)
      raise ArgumentError, "start_byte must be non-negative" if start_byte.negative?
      raise ArgumentError, "end_byte must be >= start_byte" if end_byte < start_byte

      stream_lines(bucket: @bucket, key: key, range: "bytes=#{start_byte}-#{end_byte}", &block)
    end

    private

    # Shared line-buffered streaming. Passes all keyword args to get_object,
    # buffers incoming chunks, and yields complete lines to the caller.
    def stream_lines(**get_object_params, &block)
      line_buffer = +""

      @client.get_object(**get_object_params) do |chunk, _headers|
        line_buffer << chunk

        while (newline_idx = line_buffer.index("\n"))
          line = line_buffer.slice!(0..newline_idx)
          yield line
        end
      end

      # Yield remaining content (file/range without trailing newline)
      yield line_buffer unless line_buffer.empty?
    end
  end
end
