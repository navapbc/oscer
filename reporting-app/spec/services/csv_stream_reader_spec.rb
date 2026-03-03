# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvStreamReader do
  let(:adapter) { instance_double(Storage::S3Adapter) }
  let(:reader) { described_class.new(storage_adapter: adapter) }

  describe "#each_chunk" do
    context "with a standard CSV file" do
      let(:csv_content) do
        <<~CSV
          member_id,name,hours
          1,Alice,40
          2,Bob,35
          3,Carol,45
        CSV
      end

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "yields chunks of records" do
        chunks = []
        reader.each_chunk("test.csv", chunk_size: 2) { |chunk| chunks << chunk }

        expect(chunks.size).to eq(2)
        expect(chunks[0].size).to eq(2) # First 2 records
        expect(chunks[1].size).to eq(1) # Last record
      end

      it "parses CSV into hashes with headers as keys" do
        records = []
        reader.each_chunk("test.csv") { |chunk| records.concat(chunk) }

        expect(records.first).to eq({ "member_id" => "1", "name" => "Alice", "hours" => "40" })
        expect(records.last).to eq({ "member_id" => "3", "name" => "Carol", "hours" => "45" })
      end

      it "uses default chunk size of 1000" do
        chunks = []
        reader.each_chunk("test.csv") { |chunk| chunks << chunk }

        expect(chunks.size).to eq(1) # Only 3 records, so single chunk
        expect(chunks[0].size).to eq(3)
      end
    end

    context "with an empty file" do
      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          "".each_line { |line| block.call(line) }
        end
      end

      it "yields nothing" do
        chunks = []
        reader.each_chunk("empty.csv") { |chunk| chunks << chunk }

        expect(chunks).to be_empty
      end
    end

    context "with only headers" do
      let(:csv_content) { "member_id,name,hours\n" }

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "yields nothing" do
        chunks = []
        reader.each_chunk("headers_only.csv") { |chunk| chunks << chunk }

        expect(chunks).to be_empty
      end
    end

    context "with trailing empty lines" do
      let(:csv_content) do
        <<~CSV
          member_id,name
          1,Alice
          2,Bob

        CSV
      end

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "skips empty lines" do
        records = []
        reader.each_chunk("test.csv") { |chunk| records.concat(chunk) }

        expect(records.size).to eq(2)
        expect(records.map { |r| r["name"] }).to eq([ "Alice", "Bob" ])
      end
    end

    context "with large file requiring multiple chunks" do
      before do
        # Generate CSV with 2500 records
        lines = [ "id,value\n" ]
        2500.times { |i| lines << "#{i},data#{i}\n" }

        allow(adapter).to receive(:stream_object) do |key:, &block|
          lines.each { |line| block.call(line) }
        end
      end

      it "yields correct number of chunks" do
        chunks = []
        reader.each_chunk("large.csv", chunk_size: 1000) { |chunk| chunks << chunk }

        expect(chunks.size).to eq(3)
        expect(chunks[0].size).to eq(1000)
        expect(chunks[1].size).to eq(1000)
        expect(chunks[2].size).to eq(500)
      end
    end
  end

  describe "#each_chunk_with_offsets" do
    context "with a standard CSV file" do
      let(:csv_content) { "member_id,name,hours\n1,Alice,40\n2,Bob,35\n3,Carol,45\n" }

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "yields correct records matching each_chunk output" do
        records_with_offsets = []
        reader.each_chunk_with_offsets("test.csv", chunk_size: 2) do |chunk, _headers, _start_byte, _end_byte|
          records_with_offsets.concat(chunk)
        end

        records_plain = []
        reader.each_chunk("test.csv", chunk_size: 2) { |chunk| records_plain.concat(chunk) }

        expect(records_with_offsets).to eq(records_plain)
      end

      it "yields accurate start_byte and end_byte values" do
        # Header: "member_id,name,hours\n" = 21 bytes (bytes 0-20)
        # "1,Alice,40\n" = 11 bytes (bytes 21-31)
        # "2,Bob,35\n"   =  9 bytes (bytes 32-40)
        # "3,Carol,45\n" = 11 bytes (bytes 41-51)
        # chunk_size=2: chunk 1 => start=21, end=40; chunk 2 => start=41, end=51
        offsets = []
        reader.each_chunk_with_offsets("test.csv", chunk_size: 2) do |_chunk, _headers, start_byte, end_byte|
          offsets << { start_byte: start_byte, end_byte: end_byte }
        end

        expect(offsets.size).to eq(2)
        expect(offsets[0]).to eq({ start_byte: 21, end_byte: 40 })
        expect(offsets[1]).to eq({ start_byte: 41, end_byte: 51 })
      end

      it "yields headers with each chunk" do
        headers_yielded = []
        reader.each_chunk_with_offsets("test.csv", chunk_size: 2) do |_chunk, headers, _start_byte, _end_byte|
          headers_yielded << headers
        end

        expect(headers_yielded.size).to eq(2)
        expect(headers_yielded).to all(eq(%w[member_id name hours]))
      end
    end

    context "with an empty file" do
      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          "".each_line { |line| block.call(line) }
        end
      end

      it "yields nothing" do
        chunks = []
        reader.each_chunk_with_offsets("empty.csv") { |chunk, *| chunks << chunk }

        expect(chunks).to be_empty
      end
    end

    context "with only headers" do
      let(:csv_content) { "member_id,name,hours\n" }

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "yields nothing" do
        chunks = []
        reader.each_chunk_with_offsets("headers_only.csv") { |chunk, *| chunks << chunk }

        expect(chunks).to be_empty
      end
    end

    context "with trailing and interleaved blank lines" do
      # "member_id,name\n" = 15 bytes (bytes 0-14)
      # "1,Alice\n"        =  8 bytes (bytes 15-22)
      # "\n"               =  1 byte  (byte 23, empty line skipped)
      # "2,Bob\n"          =  6 bytes (bytes 24-29)
      # "\n"               =  1 byte  (byte 30, empty line skipped)
      let(:csv_content) { "member_id,name\n1,Alice\n\n2,Bob\n\n" }

      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          csv_content.each_line { |line| block.call(line) }
        end
      end

      it "skips blank lines but tracks their bytes in offsets" do
        offsets = []
        records = []
        reader.each_chunk_with_offsets("test.csv") do |chunk, _headers, start_byte, end_byte|
          records.concat(chunk)
          offsets << { start_byte: start_byte, end_byte: end_byte }
        end

        expect(records.size).to eq(2)
        expect(records.map { |r| r["name"] }).to eq(%w[Alice Bob])

        # One chunk containing both records
        # First data line starts at byte 15, last data line ends at byte 29
        # The blank lines are skipped but their bytes are consumed by the offset counter
        expect(offsets.size).to eq(1)
        expect(offsets[0]).to eq({ start_byte: 15, end_byte: 29 })
      end
    end
  end

  describe "#read_chunk" do
    context "with valid byte range content" do
      let(:range_content) { "1,Alice,40\n2,Bob,35\n" }

      before do
        allow(adapter).to receive(:stream_object_range) do |key:, start_byte:, end_byte:, &block|
          range_content.each_line { |line| block.call(line) }
        end
      end

      it "parses byte range content into string-keyed hashes" do
        result = reader.read_chunk(
          "test.csv",
          headers: %w[member_id name hours],
          start_byte: 21,
          end_byte: 40
        )

        expect(result.size).to eq(2)
        expect(result[0]).to eq({ "member_id" => "1", "name" => "Alice", "hours" => "40" })
        expect(result[1]).to eq({ "member_id" => "2", "name" => "Bob", "hours" => "35" })
      end
    end

    context "with partial final line (no trailing newline)" do
      let(:range_content) { "1,Alice,40\n2,Bob,35" }

      before do
        allow(adapter).to receive(:stream_object_range) do |key:, start_byte:, end_byte:, &block|
          range_content.each_line { |line| block.call(line) }
        end
      end

      it "handles the line without trailing newline" do
        result = reader.read_chunk(
          "test.csv",
          headers: %w[member_id name hours],
          start_byte: 21,
          end_byte: 39
        )

        expect(result.size).to eq(2)
        expect(result[1]).to eq({ "member_id" => "2", "name" => "Bob", "hours" => "35" })
      end
    end

    context "with empty and blank lines within the range" do
      let(:range_content) { "1,Alice,40\n\n  \n2,Bob,35\n" }

      before do
        allow(adapter).to receive(:stream_object_range) do |key:, start_byte:, end_byte:, &block|
          range_content.each_line { |line| block.call(line) }
        end
      end

      it "skips empty and blank lines" do
        result = reader.read_chunk(
          "test.csv",
          headers: %w[member_id name hours],
          start_byte: 21,
          end_byte: 45
        )

        expect(result.size).to eq(2)
        expect(result[0]).to eq({ "member_id" => "1", "name" => "Alice", "hours" => "40" })
        expect(result[1]).to eq({ "member_id" => "2", "name" => "Bob", "hours" => "35" })
      end
    end

    context "when range has no valid data lines" do
      let(:range_content) { "\n  \n\n" }

      before do
        allow(adapter).to receive(:stream_object_range) do |key:, start_byte:, end_byte:, &block|
          range_content.each_line { |line| block.call(line) }
        end
      end

      it "returns an empty array" do
        result = reader.read_chunk(
          "test.csv",
          headers: %w[member_id name hours],
          start_byte: 21,
          end_byte: 25
        )

        expect(result).to eq([])
      end
    end
  end
end
