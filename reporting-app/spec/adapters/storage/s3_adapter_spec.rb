# frozen_string_literal: true

require "rails_helper"

RSpec.describe Storage::S3Adapter do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:adapter) { described_class.new(client: s3_client, bucket: "test-bucket", region: "us-east-1") }
  let(:test_key) { "uploads/test-file.csv" }

  describe "#put_object" do
    it "uploads an object to S3" do
      s3_client.stub_responses(:put_object, { etag: "abc123", version_id: "v1" })

      result = adapter.put_object(key: test_key, body: "test content")

      expect(result.etag).to eq("abc123")
      expect(result.version_id).to eq("v1")
    end

    it "passes additional options to S3" do
      # Just verify the call succeeds with additional options
      expect do
        adapter.put_object(
          key: test_key,
          body: "test content",
          content_type: "text/csv",
          metadata: { "source" => "batch_upload" }
        )
      end.not_to raise_error
    end
  end

  describe "#get_object" do
    it "downloads an object from S3" do
      s3_client.stub_responses(:get_object, { body: "file content" })

      result = adapter.get_object(key: test_key)

      expect(result).to eq("file content")
    end
  end

  describe "#delete_object" do
    it "deletes an object from S3" do
      expect do
        adapter.delete_object(key: test_key)
      end.not_to raise_error
    end
  end

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

  describe "#get_object_metadata" do
    it "returns metadata about the object" do
      s3_client.stub_responses(:head_object, {
        content_length: 1024,
        content_type: "text/csv",
        last_modified: Time.parse("2026-01-27T10:00:00Z"),
        etag: "abc123",
        metadata: { "source" => "batch_upload" }
      })

      result = adapter.get_object_metadata(key: test_key)

      expect(result[:size]).to eq(1024)
      expect(result[:content_type]).to eq("text/csv")
      expect(result[:last_modified]).to eq(Time.parse("2026-01-27T10:00:00Z"))
      expect(result[:etag]).to eq("abc123")
      expect(result[:metadata]).to eq({ "source" => "batch_upload" })
    end
  end

  describe "#generate_signed_upload_url" do
    it "generates a presigned URL for uploading" do
      result = adapter.generate_signed_upload_url(
        key: test_key,
        content_type: "text/csv",
        expires_in: 3600
      )

      expect(result[:url]).to be_a(String)
      expect(result[:url]).to include("test-bucket")
      expect(result[:url]).to include(test_key)
      expect(result[:key]).to eq(test_key)
    end

    it "accepts custom content_type and expires_in parameters" do
      expect do
        result = adapter.generate_signed_upload_url(
          key: test_key,
          content_type: "text/csv; charset=utf-8",
          expires_in: 1800
        )
        expect(result[:url]).to be_a(String)
        expect(result[:key]).to eq(test_key)
      end.not_to raise_error
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
        .and_yield("header1,he")
        .and_yield("ader2\nval")
        .and_yield("ue1,value2\n")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "header1,header2\n", "value1,value2\n" ])
    end

    it "handles file without trailing newline" do
      # Last line doesn't end with newline - should still yield it
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("header\n")
        .and_yield("last_line_no_newline")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "header\n", "last_line_no_newline" ])
    end

    it "handles multiple newlines in a single chunk" do
      # Single chunk contains multiple complete lines
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("line1\nline2\nline3\n")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "line1\n", "line2\n", "line3\n" ])
    end

    it "handles empty chunks mixed with content" do
      # Edge case: empty chunks shouldn't affect line buffering
      allow(s3_client).to receive(:get_object).with(bucket: "test-bucket", key: test_key)
        .and_yield("start")
        .and_yield("")
        .and_yield("\nend\n")

      lines = []
      adapter.stream_object(key: test_key) { |line| lines << line }

      expect(lines).to eq([ "start\n", "end\n" ])
    end
  end
end
