# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvStreamReader do
  let(:adapter) { instance_double(Storage::S3Adapter) }
  let(:reader) { described_class.new(storage_adapter: adapter) }

  describe "#each_batch" do
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

      it "yields batches of records" do
        batches = []
        reader.each_batch("test.csv", batch_size: 2) { |batch| batches << batch }

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(2) # First 2 records
        expect(batches[1].size).to eq(1) # Last record
      end

      it "parses CSV into hashes with headers as keys" do
        records = []
        reader.each_batch("test.csv") { |batch| records.concat(batch) }

        expect(records.first).to eq({ "member_id" => "1", "name" => "Alice", "hours" => "40" })
        expect(records.last).to eq({ "member_id" => "3", "name" => "Carol", "hours" => "45" })
      end

      it "uses default batch size of 1000" do
        batches = []
        reader.each_batch("test.csv") { |batch| batches << batch }

        expect(batches.size).to eq(1) # Only 3 records, so single batch
        expect(batches[0].size).to eq(3)
      end
    end

    context "with an empty file" do
      before do
        allow(adapter).to receive(:stream_object) do |key:, &block|
          "".each_line { |line| block.call(line) }
        end
      end

      it "yields nothing" do
        batches = []
        reader.each_batch("empty.csv") { |batch| batches << batch }

        expect(batches).to be_empty
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
        batches = []
        reader.each_batch("headers_only.csv") { |batch| batches << batch }

        expect(batches).to be_empty
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
        reader.each_batch("test.csv") { |batch| records.concat(batch) }

        expect(records.size).to eq(2)
        expect(records.map { |r| r["name"] }).to eq([ "Alice", "Bob" ])
      end
    end

    context "with large file requiring multiple batches" do
      before do
        # Generate CSV with 2500 records
        lines = [ "id,value\n" ]
        2500.times { |i| lines << "#{i},data#{i}\n" }

        allow(adapter).to receive(:stream_object) do |key:, &block|
          lines.each { |line| block.call(line) }
        end
      end

      it "yields correct number of batches" do
        batches = []
        reader.each_batch("large.csv", batch_size: 1000) { |batch| batches << batch }

        expect(batches.size).to eq(3)
        expect(batches[0].size).to eq(1000)
        expect(batches[1].size).to eq(1000)
        expect(batches[2].size).to eq(500)
      end
    end
  end
end
