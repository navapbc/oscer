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
end
