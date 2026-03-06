# frozen_string_literal: true

require "azure_blob"

module Storage
  # Azure Blob Storage streaming adapter for batch upload processing.
  # Active Storage handles uploads/deletes; this adapter handles efficient streaming.
  #
  # The azure-blob gem does not support block-based streaming (unlike AWS SDK).
  # Instead, we download in fixed-size byte-range chunks and buffer across
  # chunk boundaries, yielding complete lines. This keeps memory usage constant
  # (~2x DOWNLOAD_CHUNK_SIZE worst case).
  class AzureBlobAdapter < BaseAdapter
    DOWNLOAD_CHUNK_SIZE = 4.megabytes

    def initialize(client: nil, account_name: nil, access_key: nil, container: nil)
      @container = container || ENV.fetch("AZURE_CONTAINER_NAME")
      @client = client || AzureBlob::Client.new(
        account_name: account_name || ENV.fetch("AZURE_STORAGE_ACCOUNT"),
        access_key: access_key || ENV.fetch("AZURE_STORAGE_ACCESS_KEY"),
        container: @container
      )
    end

    # Check if a blob exists in Azure Blob Storage
    # @param key [String] The blob key (path) in the container
    def object_exists?(key:)
      @client.blob_exist?(key)
    end

    # Stream a blob from Azure Blob Storage line by line
    # Downloads in byte-range chunks and buffers across boundaries.
    # @param key [String] The blob key (path) in the container
    def stream_object(key:, &block)
      total_size = @client.get_blob_properties(key).size.to_i
      stream_lines(key: key, range_start: 0, range_end: total_size - 1, &block) if total_size.positive?
    end

    # Stream a byte range from a blob, line by line
    # @param key [String] The blob key (path) in the container
    # @param start_byte [Integer] Start of byte range (inclusive)
    # @param end_byte [Integer] End of byte range (inclusive)
    def stream_object_range(key:, start_byte:, end_byte:, &block)
      raise ArgumentError, "start_byte must be non-negative" if start_byte.negative?
      raise ArgumentError, "end_byte must be >= start_byte" if end_byte < start_byte

      stream_lines(key: key, range_start: start_byte, range_end: end_byte, &block)
    end

    private

    # Download in DOWNLOAD_CHUNK_SIZE byte-range increments, buffer partial
    # lines across chunk boundaries, and yield complete lines.
    def stream_lines(key:, range_start:, range_end:)
      line_buffer = +""
      offset = range_start

      while offset <= range_end
        chunk_end = [ offset + DOWNLOAD_CHUNK_SIZE - 1, range_end ].min
        chunk = @client.get_blob(key, start: offset, end: chunk_end)
        line_buffer << chunk

        while (newline_idx = line_buffer.index("\n"))
          yield line_buffer.slice!(0..newline_idx)
        end

        offset = chunk_end + 1
      end

      # Yield remaining content (file/range without trailing newline)
      yield line_buffer unless line_buffer.empty?
    end
  end
end
