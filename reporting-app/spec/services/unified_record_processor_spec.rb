# frozen_string_literal: true

require "rails_helper"

RSpec.describe UnifiedRecordProcessor do
  let(:processor) { described_class.new }

  describe "#process" do
    context "with valid record" do
      let(:record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "first_name" => "Alice",
          "last_name" => "Smith",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "creates certification" do
        allow(Strata::EventManager).to receive(:publish)

        expect { processor.process(record) }
          .to change(Certification, :count).by(1)
      end

      it "returns the created certification" do
        allow(Strata::EventManager).to receive(:publish)

        result = processor.process(record)

        expect(result).to be_a(Certification)
        expect(result).to be_persisted
        expect(result.member_id).to eq("M12345")
        expect(result.case_number).to eq("C-001")
      end

      it "builds member_data from record fields" do
        allow(Strata::EventManager).to receive(:publish)

        certification = processor.process(record)

        expect(certification.member_data.name.first).to eq("Alice")
        expect(certification.member_data.name.last).to eq("Smith")
        expect(certification.member_data.account_email).to eq("test@example.com")
      end

      it "builds certification_requirements from record fields" do
        allow(Strata::EventManager).to receive(:publish)

        certification = processor.process(record)

        expect(certification.certification_requirements.certification_date.to_s).to eq("2025-01-15")
        expect(certification.certification_requirements.certification_type).to eq("new_application")
      end

      context "when context with batch_upload_id provided" do
        let(:batch_upload) { create(:certification_batch_upload) }

        it "creates CertificationOrigin" do
          allow(Strata::EventManager).to receive(:publish)

          expect {
            processor.process(record, context: { batch_upload_id: batch_upload.id })
          }.to change(CertificationOrigin, :count).by(1)
        end

        it "links CertificationOrigin to certification and batch upload" do
          allow(Strata::EventManager).to receive(:publish)

          certification = processor.process(record, context: { batch_upload_id: batch_upload.id })

          origin = CertificationOrigin.find_by(certification_id: certification.id)
          expect(origin).to be_present
          expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD)
          expect(origin.source_id).to eq(batch_upload.id)
        end
      end

      context "when no context provided" do
        it "does not create CertificationOrigin" do
          allow(Strata::EventManager).to receive(:publish)

          expect {
            processor.process(record)
          }.not_to change(CertificationOrigin, :count)
        end
      end
    end

    context "with missing required fields" do
      UnifiedRecordProcessor::REQUIRED_FIELDS.each do |field|
        it "raises ValidationError when #{field} is missing" do
          record = {
            "member_id" => "M123",
            "case_number" => "C-001",
            "member_email" => "test@example.com",
            "certification_date" => "2025-01-15",
            "certification_type" => "new_application"
          }
          record.delete(field)

          expect { processor.process(record) }
            .to raise_error(UnifiedRecordProcessor::ValidationError, /Missing required fields/)
        end
      end

      it "lists all missing fields in error message" do
        record = { "member_id" => "M123" }

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::ValidationError) do |error|
            expect(error.message).to include("case_number")
            expect(error.message).to include("member_email")
            expect(error.code).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
          end
      end
    end

    context "with duplicate certification" do
      let(:existing_cert) do
        cert = create(:certification,
          member_id: "M12345",
          case_number: "C-001")
        cert.update_column(:certification_requirements, { "certification_date" => "2025-01-15" })
        cert
      end

      let(:record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "first_name" => "Alice",
          "last_name" => "Smith",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      before do
        existing_cert # Create the existing certification
      end

      it "raises DuplicateError" do
        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::DuplicateError)
      end

      it "includes error code in exception" do
        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::DuplicateError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Duplicate::EXISTING_CERTIFICATION)
            expect(error.message).to include("Duplicate certification")
          end
      end

      it "does not create a new certification" do
        allow(Strata::EventManager).to receive(:publish)

        expect {
          begin
            processor.process(record)
          rescue UnifiedRecordProcessor::DuplicateError
            # Swallow error
          end
        }.not_to change(Certification, :count)
      end
    end

    context "with invalid certification data" do
      let(:record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "valid@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "raises DatabaseError when save fails" do
        certification = instance_double(Certification)
        allow(processor).to receive(:build_certification).and_return(certification)
        allow(certification).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new(Certification.new)
        )

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::DatabaseError)
      end

      it "includes error code in DatabaseError" do
        certification = instance_double(Certification)
        allow(processor).to receive(:build_certification).and_return(certification)
        allow(certification).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new(Certification.new)
        )

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::DatabaseError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Database::SAVE_FAILED)
          end
      end
    end

    context "with error hierarchy" do
      it "defines ProcessingError as base" do
        expect(UnifiedRecordProcessor::ValidationError.superclass)
          .to eq(UnifiedRecordProcessor::ProcessingError)
        expect(UnifiedRecordProcessor::DuplicateError.superclass)
          .to eq(UnifiedRecordProcessor::ProcessingError)
        expect(UnifiedRecordProcessor::DatabaseError.superclass)
          .to eq(UnifiedRecordProcessor::ProcessingError)
      end

      it "ProcessingError includes code attribute" do
        error = UnifiedRecordProcessor::ProcessingError.new("TEST_001", "Test message")
        expect(error.code).to eq("TEST_001")
        expect(error.message).to eq("Test message")
      end
    end

    context "with validator integration" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "first_name" => "Alice",
          "last_name" => "Smith",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "raises ValidationError for invalid date format (VAL_002)" do
        record = base_record.merge("certification_date" => "01/15/2025")

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::ValidationError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
            expect(error.message).to include("invalid date")
          end
      end

      it "raises ValidationError for invalid email format (VAL_003)" do
        record = base_record.merge("member_email" => "not-an-email")

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::ValidationError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
            expect(error.message).to include("invalid email format")
          end
      end

      it "raises ValidationError for invalid certification_type (VAL_004)" do
        record = base_record.merge("certification_type" => "invalid_type")

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::ValidationError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Validation::INVALID_TYPE)
            expect(error.message).to include("invalid value")
          end
      end

      it "raises ValidationError for invalid integer field (VAL_005)" do
        record = base_record.merge("lookback_period" => "not-a-number")

        expect { processor.process(record) }
          .to raise_error(UnifiedRecordProcessor::ValidationError) do |error|
            expect(error.code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
            expect(error.message).to include("invalid integer value")
          end
      end
    end
  end

  describe "#validate_record" do
    let(:valid_record) do
      {
        "member_id" => "M12345",
        "case_number" => "C-001",
        "member_email" => "test@example.com",
        "certification_date" => "2025-01-15",
        "certification_type" => "new_application"
      }
    end

    it "returns valid: true for a valid record" do
      result = processor.validate_record(valid_record)

      expect(result).to eq({ valid: true })
    end

    it "returns valid: false with error details for missing fields" do
      record = { "member_id" => "M123" }

      result = processor.validate_record(record)

      expect(result[:valid]).to be false
      expect(result[:error_code]).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
      expect(result[:error_message]).to include("Missing required fields")
    end

    it "returns valid: false for invalid date format" do
      record = valid_record.merge("certification_date" => "01/15/2025")

      result = processor.validate_record(record)

      expect(result[:valid]).to be false
      expect(result[:error_code]).to eq(BatchUploadErrors::Validation::INVALID_DATE)
    end

    it "does not persist any records" do
      expect { processor.validate_record(valid_record) }
        .not_to change(Certification, :count)
    end
  end

  describe "#compound_key" do
    it "joins fields with pipe separator" do
      key = processor.compound_key("M123", "C-001", "2025-01-15")

      expect(key).to eq("M123|C-001|2025-01-15")
    end

    it "handles nil values" do
      key = processor.compound_key("M123", nil, "2025-01-15")

      expect(key).to eq("M123||2025-01-15")
    end
  end

  describe "#find_existing_duplicates" do
    before do
      allow(Strata::EventManager).to receive(:publish)
    end

    let(:records) do
      [
        {
          "member_id" => "M100",
          "case_number" => "C-100",
          "certification_date" => "2025-01-15"
        },
        {
          "member_id" => "M200",
          "case_number" => "C-200",
          "certification_date" => "2025-02-20"
        }
      ]
    end

    it "returns empty set when no existing certifications match" do
      result = processor.find_existing_duplicates(records)

      expect(result).to be_empty
    end

    it "returns compound keys for records that exist in database" do
      cert = create(:certification, member_id: "M100", case_number: "C-100")
      cert.update_column(:certification_requirements, { "certification_date" => "2025-01-15" })

      result = processor.find_existing_duplicates(records)

      expect(result).to include("M100|C-100|2025-01-15")
      expect(result).not_to include("M200|C-200|2025-02-20")
    end

    it "returns empty set when all records have blank member_ids" do
      blank_records = [ { "member_id" => "", "case_number" => "C-1" } ]

      result = processor.find_existing_duplicates(blank_records)

      expect(result).to be_empty
    end

    it "executes a single database query" do
      allow(Certification).to receive(:where).and_call_original

      processor.find_existing_duplicates(records)

      expect(Certification).to have_received(:where).once
    end
  end

  describe "#bulk_persist!" do
    before do
      allow(Strata::EventManager).to receive(:publish)
    end

    let(:valid_records) do
      [
        {
          "member_id" => "M100",
          "case_number" => "C-100",
          "member_email" => "test1@example.com",
          "first_name" => "Alice",
          "last_name" => "One",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        },
        {
          "member_id" => "M200",
          "case_number" => "C-200",
          "member_email" => "test2@example.com",
          "first_name" => "Bob",
          "last_name" => "Two",
          "certification_date" => "2025-02-20",
          "certification_type" => "new_application"
        }
      ]
    end

    it "creates certifications via bulk insert" do
      expect {
        processor.bulk_persist!(valid_records, {})
      }.to change(Certification, :count).by(2)
    end

    it "returns array of certification IDs" do
      ids = processor.bulk_persist!(valid_records, {})

      expect(ids).to be_an(Array)
      expect(ids.size).to eq(2)
      expect(Certification.where(id: ids).count).to eq(2)
    end

    it "correctly serializes JSONB attributes (round-trip)" do
      ids = processor.bulk_persist!(valid_records, {})

      cert = Certification.find(ids.first)
      expect(cert.member_id).to eq("M100")
      expect(cert.case_number).to eq("C-100")
      expect(cert.certification_requirements.certification_date.to_s).to eq("2025-01-15")
      expect(cert.certification_requirements.certification_type).to eq("new_application")
      expect(cert.member_data.name.first).to eq("Alice")
      expect(cert.member_data.account_email).to eq("test1@example.com")
    end

    it "publishes CertificationCreated event for each certification" do
      ids = processor.bulk_persist!(valid_records, {})

      ids.each do |cert_id|
        expect(Strata::EventManager).to have_received(:publish)
          .with("CertificationCreated", { certification_id: cert_id })
      end
    end

    it "creates CertificationOrigins when batch_upload_id provided" do
      batch_upload = create(:certification_batch_upload)

      expect {
        processor.bulk_persist!(valid_records, { batch_upload_id: batch_upload.id })
      }.to change(CertificationOrigin, :count).by(2)

      origins = CertificationOrigin.last(2)
      origins.each do |origin|
        expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD)
        expect(origin.source_id).to eq(batch_upload.id)
      end
    end

    it "does not create CertificationOrigins without batch_upload_id" do
      expect {
        processor.bulk_persist!(valid_records, {})
      }.not_to change(CertificationOrigin, :count)
    end

    it "returns empty array for empty input" do
      result = processor.bulk_persist!([], {})

      expect(result).to eq([])
    end

    it "continues publishing events if one fails" do
      allow(Strata::EventManager).to receive(:publish).and_raise(StandardError, "event error")
      allow(Rails.logger).to receive(:error)

      # Should not raise despite event publish failures
      ids = processor.bulk_persist!(valid_records, {})

      expect(ids.size).to eq(2)
      expect(Rails.logger).to have_received(:error).twice
    end

    it "wraps inserts in a transaction (both or neither)" do
      batch_upload = create(:certification_batch_upload)
      # Force CertificationOrigin.insert_all! to fail
      allow(CertificationOrigin).to receive(:insert_all!).and_raise(ActiveRecord::RecordNotUnique, "duplicate")

      expect {
        processor.bulk_persist!(valid_records, { batch_upload_id: batch_upload.id })
      }.to raise_error(ActiveRecord::RecordNotUnique)

      # Transaction rollback means no certifications created
      expect(Certification.where(member_id: %w[M100 M200]).count).to eq(0)
    end
  end
end
