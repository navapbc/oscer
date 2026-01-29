# frozen_string_literal: true

require "csv"

class CsvStreamReader
  DEFAULT_BATCH_SIZE = 1_000

  def initialize(storage_adapter: nil)
    @storage = storage_adapter || Rails.application.config.storage_adapter
  end

  # Stream a CSV file from storage and yield batches of parsed records
  # @param storage_key [String] The object key in storage
  # @param batch_size [Integer] Number of records per batch
  # @yield [Array<Hash>] Array of parsed CSV records as hashes
  # @return [void]
  def each_batch(storage_key, batch_size: DEFAULT_BATCH_SIZE)
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

      # Yield batch when buffer is full
      if buffer.size >= batch_size
        yield buffer
        buffer = []
      end
    end

    # Yield remaining records
    yield buffer unless buffer.empty?
  end
end
