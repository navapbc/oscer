# frozen_string_literal: true

require "rails_helper"

RSpec.describe Storage::S3Adapter do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:adapter) { described_class.new(client: s3_client, bucket: "test-bucket", region: "us-east-1") }
  let(:test_key) { "uploads/test-file.csv" }

  describe "#object_exists?" do
    it "returns true when object exists" do
      s3_client.stub_responses(:head_object, {
        content_length: 1024,
        content_type: "text/csv"
      })

      expect(adapter.object_exists?(key: test_key)).to be true
    end

    it "returns false when object does not exist" do
      s3_client.stub_responses(:head_object, "NotFound")

      expect(adapter.object_exists?(key: test_key)).to be false
    end
  end

  describe "#stream_object" do
    it "yields lines from the object" do
      csv_content = "header1,header2\nvalue1,value2\nvalue3,value4\n"
      s3_client.stub_responses(:get_object, { body: csv_content })

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines.size).to eq(3)
      expect(lines[0]).to eq("header1,header2\n")
      expect(lines[1]).to eq("value1,value2\n")
      expect(lines[2]).to eq("value3,value4\n")
    end

    it "handles empty files" do
      s3_client.stub_responses(:get_object, { body: "" })

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to be_empty
    end

    it "handles lines split across chunks" do
      # Simulate AWS SDK streaming chunks that split lines mid-content
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("header1,he", nil)
        .and_yield("ader2\nval", nil)
        .and_yield("ue1,value2\n", nil)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "header1,header2\n", "value1,value2\n" ])
    end

    it "handles file without trailing newline" do
      # Last line doesn't end with newline - should still yield it
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("header\n", nil)
        .and_yield("last_line_no_newline", nil)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "header\n", "last_line_no_newline" ])
    end

    it "handles multiple newlines in a single chunk" do
      # Single chunk contains multiple complete lines
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("line1\nline2\nline3\n", nil)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "line1\n", "line2\n", "line3\n" ])
    end

    it "handles empty chunks mixed with content" do
      # Edge case: empty chunks shouldn't affect line buffering
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("start", nil)
        .and_yield("", nil)
        .and_yield("\nend\n", nil)

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "start\n", "end\n" ])
    end
  end
end
