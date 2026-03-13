# frozen_string_literal: true

require "rails_helper"

RSpec.describe StagedDocument, type: :model do
  describe "validations" do
    it "is valid with a user and attached file" do
      doc = build(:staged_document)
      expect(doc).to be_valid
    end

    it "is invalid without a user" do
      doc = build(:staged_document, user_id: nil)
      expect(doc).not_to be_valid
    end

    it "is invalid without an attached file" do
      doc = build(:staged_document)
      doc.file.detach
      expect(doc).not_to be_valid
      expect(doc.errors[:file]).to be_present
    end

    it "is invalid without a status" do
      doc = build(:staged_document)
      doc.status = nil
      expect(doc).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs_to stageable polymorphically and is optional" do
      doc = create(:staged_document)
      expect(doc.stageable).to be_nil
    end
  end

  describe "enum status" do
    let(:staged_document) { build(:staged_document) }

    it "defaults to pending" do
      expect(staged_document.status).to eq("pending")
    end

    it "can be set to validated" do
      staged_document.status = :validated
      expect(staged_document.validated?).to be true
    end

    it "can be set to rejected" do
      staged_document.status = :rejected
      expect(staged_document.rejected?).to be true
    end

    it "can be set to failed" do
      staged_document.status = :failed
      expect(staged_document.failed?).to be true
    end
  end

  describe "factory" do
    it "creates a valid staged_document" do
      expect(create(:staged_document)).to be_persisted
    end

    it "creates a validated staged_document with :validated trait" do
      doc = create(:staged_document, :validated)
      expect(doc.validated?).to be true
      expect(doc.doc_ai_job_id).to be_present
    end

    it "creates a rejected staged_document with :rejected trait" do
      doc = create(:staged_document, :rejected)
      expect(doc.rejected?).to be true
    end

    it "creates a failed staged_document with :failed trait" do
      doc = create(:staged_document, :failed)
      expect(doc.failed?).to be true
    end
  end

  describe "extracted_fields" do
    it "defaults to empty hash" do
      doc = create(:staged_document)
      expect(doc.extracted_fields).to eq({})
    end

    it "stores JSONB data" do
      fields = { "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 } }
      doc = create(:staged_document, extracted_fields: fields)
      doc.reload
      expect(doc.extracted_fields).to eq(fields)
    end
  end

  describe "#average_confidence" do
    it "returns nil for empty extracted_fields" do
      doc = build(:staged_document, extracted_fields: {})
      expect(doc.average_confidence).to be_nil
    end

    it "returns nil for nil extracted_fields" do
      doc = build(:staged_document, extracted_fields: nil)
      expect(doc.average_confidence).to be_nil
    end

    it "returns the confidence value when there is a single field" do
      doc = build(:staged_document, extracted_fields: {
        "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }
      })
      expect(doc.average_confidence).to eq(0.93)
    end

    it "returns the mean confidence for multiple fields" do
      doc = build(:staged_document, extracted_fields: {
        "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 },
        "payperiod" => { "confidence" => 0.87, "value" => "2024-01-15" }
      })
      expect(doc.average_confidence).to eq(0.90)
    end

    it "ignores fields without a confidence key" do
      doc = build(:staged_document, extracted_fields: {
        "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 },
        "employer_name" => { "value" => "Acme Corp" }
      })
      expect(doc.average_confidence).to eq(0.93)
    end

    it "returns nil when no fields have confidence keys" do
      doc = build(:staged_document, extracted_fields: {
        "employer_name" => { "value" => "Acme Corp" }
      })
      expect(doc.average_confidence).to be_nil
    end
  end

  describe "has_one_attached :file" do
    it "has a file attachment" do
      doc = create(:staged_document)
      expect(doc.file).to be_attached
    end
  end
end
