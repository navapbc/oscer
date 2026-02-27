# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiResult do
  let(:payslip_response) do
    {
      "job_id"                    => "d773fa8f-3cc7-47d8-be78-4125c190c290",
      "status"                    => "completed",
      "matchedDocumentClass"      => "Payslip",
      "message"                   => "Document processed successfully",
      "createdAt"                 => "2026-02-23T18:26:50.830294+00:00",
      "completedAt"               => "2026-02-23T18:27:29.434195+00:00",
      "totalProcessingTimeSeconds" => 38.6,
      "fields" => {
        "payperiodstartdate" => { "confidence" => 0.91, "value" => "2017-07-10" },
        "currentgrosspay"    => { "confidence" => 0.93, "value" => 1627.74 },
        "isgrosspayvali"     => { "confidence" => 0.87, "value" => true }
      }
    }
  end

  let(:w2_response) do
    {
      "job_id"               => "e8b21c94-5d4f-48a9-bc91-37d6f4a09c11",
      "status"               => "completed",
      "matchedDocumentClass" => "W2",
      "fields" => {
        "employerInfo.employerName"                     => { "confidence" => 0.92, "value" => "University of North Carolina" },
        "federalWageInfo.wagesTipsOtherCompensation"    => { "confidence" => 0.94, "value" => 31964.00 }
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

  let(:unknown_response) do
    {
      "job_id"               => "abc123",
      "status"               => "completed",
      "matchedDocumentClass" => "BankStatement",
      "fields"               => {}
    }
  end

  describe ".from_response" do
    it "dispatches to DocAiResult::Payslip for Payslip documents" do
      result = described_class.from_response(payslip_response)
      expect(result).to be_a(DocAiResult::Payslip)
    end

    it "dispatches to DocAiResult::W2 for W2 documents" do
      result = described_class.from_response(w2_response)
      expect(result).to be_a(DocAiResult::W2)
    end

    it "falls back to DocAiResult for unregistered document types" do
      result = described_class.from_response(unknown_response)
      expect(result).to be_a(described_class)
      expect(result).not_to be_a(DocAiResult::Payslip)
      expect(result).not_to be_a(DocAiResult::W2)
    end
  end

  describe ".build" do
    subject(:result) { described_class.build(payslip_response) }

    it "sets job_id" do
      expect(result.job_id).to eq("d773fa8f-3cc7-47d8-be78-4125c190c290")
    end

    it "sets status" do
      expect(result.status).to eq("completed")
    end

    it "sets matched_document_class" do
      expect(result.matched_document_class).to eq("Payslip")
    end

    it "freezes the fields hash" do
      expect(result.fields).to be_frozen
    end
  end

  describe "#completed?" do
    it "returns true when status is completed" do
      result = described_class.build(payslip_response)
      expect(result.completed?).to be true
    end

    it "returns false when status is failed" do
      result = described_class.build(failed_response)
      expect(result.completed?).to be false
    end
  end

  describe "#failed?" do
    it "returns true when status is failed" do
      result = described_class.build(failed_response)
      expect(result.failed?).to be true
    end

    it "returns false when status is completed" do
      result = described_class.build(payslip_response)
      expect(result.failed?).to be false
    end
  end

  describe "#field_for" do
    subject(:result) { described_class.build(payslip_response) }

    it "returns a FieldValue for a known field" do
      field = result.field_for("payperiodstartdate")
      expect(field).to be_a(DocAiResult::FieldValue)
      expect(field.value).to eq("2017-07-10")
      expect(field.confidence).to eq(0.91)
    end

    it "returns nil for an unknown field" do
      expect(result.field_for("nonexistent")).to be_nil
    end
  end

  describe "FieldValue" do
    let(:threshold) { Rails.application.config.doc_ai[:low_confidence_threshold] }

    it "reports low_confidence? when confidence is below threshold" do
      fv = DocAiResult::FieldValue.new(value: "test", confidence: threshold - 0.1)
      expect(fv.low_confidence?).to be true
    end

    it "reports low_confidence? as false when confidence meets threshold" do
      fv = DocAiResult::FieldValue.new(value: "test", confidence: threshold)
      expect(fv.low_confidence?).to be false
    end

    it "reports low_confidence? when confidence is nil" do
      fv = DocAiResult::FieldValue.new(value: "test", confidence: nil)
      expect(fv.low_confidence?).to be true
    end

    it "converts to string via value" do
      fv = DocAiResult::FieldValue.new(value: "hello", confidence: 0.9)
      expect(fv.to_s).to eq("hello")
    end
  end

  describe "REGISTRY" do
    it "is frozen" do
      expect(DocAiResult::REGISTRY).to be_frozen
    end

    it "includes Payslip" do
      expect(DocAiResult::REGISTRY["Payslip"]).to eq(DocAiResult::Payslip)
    end

    it "includes W2" do
      expect(DocAiResult::REGISTRY["W2"]).to eq(DocAiResult::W2)
    end
  end

  describe "#to_prefill_fields" do
    it "returns empty hash for base DocAiResult" do
      result = described_class.build(unknown_response)
      expect(result.to_prefill_fields).to eq({})
    end
  end
end
