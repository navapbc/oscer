# frozen_string_literal: true

require "csv"

class CsvStreamReader
  DEFAULT_CHUNK_SIZE = 1_000

  def initialize(storage_adapter: nil)
    @storage = storage_adapter || Rails.application.config.storage_adapter
  end

  # Stream a CSV file from storage and yield chunks of parsed records
  # @param storage_key [String] The object key in storage
  # @param chunk_size [Integer] Number of records per chunk
  # @yield [Array<Hash>] Array of parsed CSV records as hashes
  # @return [void]
  def each_chunk(storage_key, chunk_size: DEFAULT_CHUNK_SIZE)
    headers = nil
    buffer = []

    @storage.stream_object(key: storage_key) do |line|
      # Skip empty lines
      next if line.strip.empty?

      # Parse headers from first line
      if headers.nil?
        headers = CSV.parse_line(line.strip)
        next
      end

      # Parse record
      values = CSV.parse_line(line.strip)
      next if values.nil? || values.empty? || values.all?(&:nil?)

      # Convert to hash and add to buffer
      record = headers.zip(values).to_h
      buffer << record

      # Yield chunk when buffer is full
      if buffer.size >= chunk_size
        yield buffer
        buffer = []
      end
    end

    # Yield remaining records
    yield buffer unless buffer.empty?
  end

  # Stream a CSV file and yield chunks with byte offset tracking.
  # Offsets enable re-reading specific byte ranges from storage later.
  # @param storage_key [String] The object key in storage
  # @param chunk_size [Integer] Number of records per chunk
  # @yield [Array<Hash>, Array<String>, Integer, Integer] records, headers, start_byte, end_byte
  # @return [void]
  def each_chunk_with_offsets(storage_key, chunk_size: DEFAULT_CHUNK_SIZE)
    current_offset = 0
    headers = nil
    buffer = []
    chunk_start = nil
    chunk_end = nil

    @storage.stream_object(key: storage_key) do |line|
      line_start = current_offset
      current_offset += line.bytesize

      # Skip empty lines (offset still advances)
      next if line.strip.empty?

      # Parse headers from first non-empty line
      if headers.nil?
        headers = CSV.parse_line(line.strip)
        next
      end

      # Parse record
      values = CSV.parse_line(line.strip)
      next if values.nil? || values.empty? || values.all?(&:nil?)

      # Track byte offsets for this chunk
      chunk_start = line_start if buffer.empty?
      chunk_end = current_offset - 1

      # Convert to hash and add to buffer
      record = headers.zip(values).to_h
      buffer << record

      # Yield chunk when buffer is full
      if buffer.size >= chunk_size
        yield buffer, headers, chunk_start, chunk_end
        buffer = []
        chunk_start = nil
        chunk_end = nil
      end
    end

    # Yield remaining records
    yield buffer, headers, chunk_start, chunk_end unless buffer.empty?
  end

  # Read a specific byte range from storage and parse it as CSV data lines.
  # Used to re-read a chunk previously identified by each_chunk_with_offsets.
  # @param storage_key [String] The object key in storage
  # @param headers [Array<String>] CSV column headers to zip with values
  # @param start_byte [Integer] First byte of the range (inclusive)
  # @param end_byte [Integer] Last byte of the range (inclusive)
  # @return [Array<Hash>] Parsed records as string-keyed hashes
  def read_chunk(storage_key, headers:, start_byte:, end_byte:)
    records = []

    @storage.stream_object_range(key: storage_key, start_byte: start_byte, end_byte: end_byte) do |line|
      next if line.strip.empty?

      values = CSV.parse_line(line.strip)
      next if values.nil? || values.empty? || values.all?(&:nil?)

      records << headers.zip(values).to_h
    end

    records
  end
end
