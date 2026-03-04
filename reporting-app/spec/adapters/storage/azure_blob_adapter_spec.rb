# frozen_string_literal: true

require "rails_helper"

RSpec.describe Storage::AzureBlobAdapter do
  let(:client) { instance_double(AzureBlob::Client) }
  let(:adapter) { described_class.new(client: client, container: "test-container") }
  let(:test_key) { "uploads/test-file.csv" }

  describe "#object_exists?" do
    it "returns true when blob exists" do
      allow(client).to receive(:blob_exist?).with(test_key).and_return(true)

      expect(adapter.object_exists?(key: test_key)).to be true
    end

    it "returns false when blob does not exist" do
      allow(client).to receive(:blob_exist?).with(test_key).and_return(false)

      expect(adapter.object_exists?(key: test_key)).to be false
    end
  end

  describe "#stream_object" do
    it "yields lines from the blob" do
      blob_props = instance_double(AzureBlob::Blob, size: 46)
      csv_content = "header1,header2\nvalue1,value2\nvalue3,value4\n"

      allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)
      allow(client).to receive(:get_blob).with(test_key, start: 0, end: 45).and_return(csv_content)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq(
        [
          "header1,header2\n",
          "value1,value2\n",
          "value3,value4\n"
        ]
      )
    end

    it "handles empty files" do
      blob_props = instance_double(AzureBlob::Blob, size: 0)
      allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to be_empty
    end

    it "lets FileNotFoundError propagate when blob does not exist" do
      allow(client).to receive(:get_blob_properties)
        .with(test_key)
        .and_raise(AzureBlob::Http::FileNotFoundError)

      expect {
        adapter.stream_object(key: test_key) { |_| }
      }.to raise_error(AzureBlob::Http::FileNotFoundError)
    end

    it "handles file exactly one chunk in size" do
      stub_const("Storage::AzureBlobAdapter::DOWNLOAD_CHUNK_SIZE", 12)
      blob_props = instance_double(AzureBlob::Blob, size: 12)
      allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)
      allow(client).to receive(:get_blob).with(test_key, start: 0, end: 11).and_return("line1\nline2\n")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "line1\n", "line2\n" ])
    end

    context "with lines split across download chunks" do
      before { stub_const("Storage::AzureBlobAdapter::DOWNLOAD_CHUNK_SIZE", 10) }

      it "buffers partial lines across chunk boundaries" do
        blob_props = instance_double(AzureBlob::Blob, size: 25)
        allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)
        allow(client).to receive(:get_blob).with(test_key, start: 0, end: 9).and_return("header1,he")
        allow(client).to receive(:get_blob).with(test_key, start: 10, end: 19).and_return("ader2\nval1")
        allow(client).to receive(:get_blob).with(test_key, start: 20, end: 24).and_return(",v2\n\n")

        lines = []
        adapter.stream_object(key: test_key) { |line| lines << line }

        expect(lines).to eq([ "header1,header2\n", "val1,v2\n", "\n" ])
      end
    end

    it "handles file without trailing newline" do
      blob_props = instance_double(AzureBlob::Blob, size: 26)
      allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)
      allow(client).to receive(:get_blob)
        .with(test_key, start: 0, end: 25)
        .and_return("header\nlast_line_no_newline")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "header\n", "last_line_no_newline" ])
    end

    it "handles multiple newlines in a single chunk" do
      blob_props = instance_double(AzureBlob::Blob, size: 18)
      allow(client).to receive(:get_blob_properties).with(test_key).and_return(blob_props)
      allow(client).to receive(:get_blob)
        .with(test_key, start: 0, end: 17)
        .and_return("line1\nline2\nline3\n")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "line1\n", "line2\n", "line3\n" ])
    end
  end

  describe "#stream_object_range" do
    it "yields lines from the byte range" do
      csv_content = "header1,header2\nvalue1,value2\nvalue3,value4\n"
      allow(client).to receive(:get_blob)
        .with(test_key, start: 0, end: 100)
        .and_return(csv_content)

      lines = []
      adapter.stream_object_range(key: test_key, start_byte: 0, end_byte: 100) { |line| lines << line }

      expect(lines).to eq(
        [
          "header1,header2\n",
          "value1,value2\n",
          "value3,value4\n"
        ]
      )
    end

    context "with lines split across download chunks" do
      before { stub_const("Storage::AzureBlobAdapter::DOWNLOAD_CHUNK_SIZE", 10) }

      it "buffers partial lines across chunk boundaries within range" do
        allow(client).to receive(:get_blob).with(test_key, start: 0, end: 9).and_return("header1,he")
        allow(client).to receive(:get_blob).with(test_key, start: 10, end: 19).and_return("ader2\nval1")
        allow(client).to receive(:get_blob).with(test_key, start: 20, end: 24).and_return(",v2\n\n")

        lines = []
        adapter.stream_object_range(key: test_key, start_byte: 0, end_byte: 24) { |line| lines << line }

        expect(lines).to eq([ "header1,header2\n", "val1,v2\n", "\n" ])
      end

      it "handles non-zero start_byte with multiple chunks" do
        allow(client).to receive(:get_blob).with(test_key, start: 50, end: 59).and_return("ue1,value2")
        allow(client).to receive(:get_blob).with(test_key, start: 60, end: 69).and_return("\nvalue3,va")
        allow(client).to receive(:get_blob).with(test_key, start: 70, end: 74).and_return("lue4\n")

        lines = []
        adapter.stream_object_range(key: test_key, start_byte: 50, end_byte: 74) { |line| lines << line }

        expect(lines).to eq([ "ue1,value2\n", "value3,value4\n" ])
      end
    end

    it "handles empty range content" do
      allow(client).to receive(:get_blob)
        .with(test_key, start: 0, end: 0)
        .and_return("")

      lines = []
      adapter.stream_object_range(key: test_key, start_byte: 0, end_byte: 0) { |line| lines << line }

      expect(lines).to be_empty
    end

    it "handles single-byte range (start_byte equals end_byte)" do
      allow(client).to receive(:get_blob)
        .with(test_key, start: 5, end: 5)
        .and_return("x")

      lines = []
      adapter.stream_object_range(key: test_key, start_byte: 5, end_byte: 5) { |line| lines << line }

      expect(lines).to eq([ "x" ])
    end

    it "raises ArgumentError for negative start_byte" do
      expect {
        adapter.stream_object_range(key: test_key, start_byte: -1, end_byte: 10) { |_| }
      }.to raise_error(ArgumentError, "start_byte must be non-negative")
    end

    it "raises ArgumentError when end_byte < start_byte" do
      expect {
        adapter.stream_object_range(key: test_key, start_byte: 10, end_byte: 5) { |_| }
      }.to raise_error(ArgumentError, "end_byte must be >= start_byte")
    end
  end
end
