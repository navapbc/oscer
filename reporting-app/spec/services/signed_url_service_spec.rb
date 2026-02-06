# frozen_string_literal: true

require "rails_helper"

RSpec.describe SignedUrlService do
  let(:adapter) { instance_double(Storage::S3Adapter) }
  let(:service) { described_class.new(storage_adapter: adapter) }

  describe "#generate_upload_url" do
    before do
      allow(adapter).to receive(:generate_signed_upload_url)
        .and_return({ url: "https://bucket.s3.amazonaws.com/...", key: "batch-uploads/uuid/test.csv" })
    end

    it "returns url and key" do
      result = service.generate_upload_url(filename: "members.csv")

      expect(result).to include(:url, :key)
    end

    it "generates unique keys with UUID prefix for each request" do
      allow(adapter).to receive(:generate_signed_upload_url) do |args|
        { url: "https://example.com/url", key: args[:key] }
      end

      result1 = service.generate_upload_url(filename: "file.csv")
      result2 = service.generate_upload_url(filename: "file.csv")

      expect(result1[:key]).to match(%r{batch-uploads/[a-f0-9-]+/file\.csv})
      expect(result2[:key]).to match(%r{batch-uploads/[a-f0-9-]+/file\.csv})
      expect(result1[:key]).not_to eq(result2[:key])
    end

    it "passes content_type to adapter" do
      service.generate_upload_url(filename: "data.csv", content_type: "application/json")

      expect(adapter).to have_received(:generate_signed_upload_url)
        .with(hash_including(content_type: "application/json"))
    end

    it "uses default content_type of text/csv" do
      service.generate_upload_url(filename: "data.csv")

      expect(adapter).to have_received(:generate_signed_upload_url)
        .with(hash_including(content_type: "text/csv"))
    end

    it "passes expires_in to adapter" do
      service.generate_upload_url(filename: "data.csv", expires_in: 7200)

      expect(adapter).to have_received(:generate_signed_upload_url)
        .with(hash_including(expires_in: 7200))
    end

    it "uses default expiry of 1 hour" do
      service.generate_upload_url(filename: "data.csv")

      expect(adapter).to have_received(:generate_signed_upload_url)
        .with(hash_including(expires_in: 3600))
    end

    it "preserves original filename in storage key" do
      allow(adapter).to receive(:generate_signed_upload_url) do |args|
        { url: "https://example.com/url", key: args[:key] }
      end

      result = service.generate_upload_url(filename: "my-members-2026.csv")

      expect(result[:key]).to end_with("/my-members-2026.csv")
    end

    context "with malicious filenames" do
      it "rejects filenames with forward slashes" do
        expect {
          service.generate_upload_url(filename: "../../etc/passwd")
        }.to raise_error(ArgumentError, "Filename must not contain path separators")
      end

      it "rejects filenames with backslashes" do
        expect {
          service.generate_upload_url(filename: "..\\..\\windows\\system32")
        }.to raise_error(ArgumentError, "Filename must not contain path separators")
      end
    end
  end
end
