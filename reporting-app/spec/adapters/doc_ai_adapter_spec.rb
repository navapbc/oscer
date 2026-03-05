# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiAdapter do
  let(:api_host) { "https://app-docai.example.com" }
  let(:connection) do
    Faraday.new(url: api_host) do |f|
      f.request :multipart
      f.request :url_encoded
      f.response :json
      f.adapter :test, stubs
    end
  end
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:adapter) { described_class.new(connection: connection) }

  let(:file_double) do
    tempfile = Tempfile.new([ "test", ".pdf" ])
    tempfile.write("%PDF-1.4 test content")
    tempfile.rewind

    blob = instance_double(
      ActiveStorage::Blob,
      content_type: "application/pdf",
      filename: ActiveStorage::Filename.new("test.pdf")
    )
    allow(blob).to receive(:open).and_yield(tempfile)

    # rubocop:disable RSpec/VerifiedDoubles
    # ActiveStorage::Attached::One delegates blob via record/name; not directly verifiable
    double(
      "ActiveStorage::Attached::One",
      blob: blob,
      content_type: "application/pdf",
      filename: ActiveStorage::Filename.new("test.pdf")
    )
    # rubocop:enable RSpec/VerifiedDoubles
  end

  let(:success_response_body) do
    {
      "job_id"               => "d773fa8f-3cc7-47d8-be78-4125c190c290",
      "status"               => "completed",
      "matchedDocumentClass" => "Payslip",
      "message"              => "Document processed successfully",
      "fields" => {
        "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }
      }
    }
  end

  describe "#analyze_document" do
    context "when the request is successful (200)" do
      before do
        stubs.post("/v1/documents") do
          [ 200, { "Content-Type" => "application/json" }, success_response_body.to_json ]
        end
      end

      it "sends wait=true query param and returns the parsed response body" do
        result = adapter.analyze_document(file: file_double)
        expect(result["job_id"]).to eq("d773fa8f-3cc7-47d8-be78-4125c190c290")
        expect(result["matchedDocumentClass"]).to eq("Payslip")
      end
    end

    context "when the request returns a 4xx error" do
      let(:error_body) { { "detail" => "There was an error parsing the body" } }

      before do
        stubs.post("/v1/documents") do
          [ 422, { "Content-Type" => "application/json" }, error_body.to_json ]
        end
      end

      it "raises an ApiError with the detail message" do
        expect { adapter.analyze_document(file: file_double) }
          .to raise_error(DocAiAdapter::ApiError, "There was an error parsing the body")
      end
    end

    context "when the request returns a 5xx server error" do
      before do
        stubs.post("/v1/documents") do
          [ 500, {}, "Internal Server Error" ]
        end
      end

      it "raises a ServerError" do
        expect { adapter.analyze_document(file: file_double) }
          .to raise_error(DocAiAdapter::ServerError)
      end
    end

    context "when a network timeout occurs" do
      before do
        stubs.post("/v1/documents") { raise Faraday::TimeoutError }
      end

      it "raises an ApiError" do
        expect { adapter.analyze_document(file: file_double) }
          .to raise_error(DocAiAdapter::ApiError)
      end
    end

    context "when there is no detail in 4xx response body" do
      before do
        stubs.post("/v1/documents") do
          [ 400, { "Content-Type" => "application/json" }, "{}" ]
        end
      end

      it "raises an ApiError with status code" do
        expect { adapter.analyze_document(file: file_double) }
          .to raise_error(DocAiAdapter::ApiError, /DocAI error: 400/)
      end
    end
  end
end
