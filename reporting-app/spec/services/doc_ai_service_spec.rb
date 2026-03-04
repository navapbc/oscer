# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiService do
  let(:adapter) { instance_double(DocAiAdapter) }
  let(:service) { described_class.new(adapter: adapter) }

  let(:file_double) { instance_double(ActiveStorage::Attached::One) }

  let(:payslip_response) do
    {
      "job_id"                     => "d773fa8f-3cc7-47d8-be78-4125c190c290",
      "status"                     => "completed",
      "matchedDocumentClass"       => "Payslip",
      "message"                    => "Document processed successfully",
      "totalProcessingTimeSeconds" => 38.6,
      "fields" => {
        "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }
      }
    }
  end

  let(:failed_response) do
    {
      "job_id" => "a4187dd2-8ccd-4e6f-b7a7-164092e49eca",
      "status" => "failed",
      "error"  => "Handler handler failed"
    }
  end

  describe "#analyze" do
    context "when the adapter returns a successful Payslip response" do
      before do
        allow(adapter).to receive(:analyze_document).with(file: file_double)
          .and_return(payslip_response)
      end

      it "returns a DocAiResult::Payslip" do
        result = service.analyze(file: file_double)
        expect(result).to be_a(DocAiResult::Payslip)
      end

      it "returns the result with the correct job_id" do
        result = service.analyze(file: file_double)
        expect(result.job_id).to eq("d773fa8f-3cc7-47d8-be78-4125c190c290")
      end

      it "logs the job info" do
        allow(Rails.logger).to receive(:info)
        service.analyze(file: file_double)
        expect(Rails.logger).to have_received(:info)
          .with(a_string_including("DocAiService", "d773fa8f-3cc7-47d8-be78-4125c190c290"))
      end
    end

    context "when the adapter returns a failed status response" do
      before do
        allow(adapter).to receive(:analyze_document).with(file: file_double)
          .and_return(failed_response)
      end

      it "returns nil via handle_integration_error" do
        result = service.analyze(file: file_double)
        expect(result).to be_nil
      end

      it "logs a warning" do
        allow(Rails.logger).to receive(:warn)
        service.analyze(file: file_double)
        expect(Rails.logger).to have_received(:warn).with(a_string_including("DocAiService"))
      end
    end

    context "when the adapter raises an ApiError" do
      before do
        allow(adapter).to receive(:analyze_document).with(file: file_double)
          .and_raise(DocAiAdapter::ApiError, "connection error")
      end

      it "returns nil" do
        result = service.analyze(file: file_double)
        expect(result).to be_nil
      end

      it "logs a warning" do
        allow(Rails.logger).to receive(:warn)
        service.analyze(file: file_double)
        expect(Rails.logger).to have_received(:warn)
          .with(a_string_including("DocAiService", "connection error"))
      end
    end
  end
end
