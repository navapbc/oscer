# frozen_string_literal: true

module Storage
  # Base adapter defining the streaming interface for cloud storage.
  # Active Storage handles uploads/deletes; this adapter handles efficient streaming.
  # All storage adapters must implement these methods.
  class BaseAdapter
    def initialize(**options)
      # Subclasses define their own initialization parameters
    end

    # Check if an object exists in storage (used for validation)
    # @param key [String] The object key (path) in the bucket
    def object_exists?(key:)
      raise NotImplementedError
    end

    # Stream an object from storage line by line with constant memory usage
    # Suitable for text files (CSV, logs, etc.). Streams data without loading
    # the entire file into memory, making it suitable for large files.
    # @param key [String] The object key (path) in the bucket
    def stream_object(key:, &block)
      raise NotImplementedError
    end

    # Stream a byte range from an object in storage, line by line
    # Used by chunk jobs to re-read their slice of a CSV file from S3
    # @param key [String] The object key (path) in the bucket
    # @param start_byte [Integer] Start of byte range (inclusive, must be >= 0)
    # @param end_byte [Integer] End of byte range (inclusive, must be >= start_byte)
    def stream_object_range(key:, start_byte:, end_byte:, &block)
      raise NotImplementedError
    end
  end
end
