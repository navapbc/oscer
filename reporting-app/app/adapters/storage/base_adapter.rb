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
  end
end
