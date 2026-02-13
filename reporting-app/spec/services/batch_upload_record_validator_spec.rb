# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchUploadRecordValidator do
  let(:validator) { described_class.new }

  describe "#validate" do
    context "with valid record" do
      let(:valid_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application",
          "first_name" => "Alice",
          "last_name" => "Smith",
          "lookback_period" => "90",
          "number_of_months_to_certify" => "6",
          "due_period_days" => "30",
          "work_hours" => "20"
        }
      end

      it "returns success result" do
        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
        expect(result.error_code).to be_nil
        expect(result.error_message).to be_nil
      end

      it "accepts new_application certification type" do
        valid_record["certification_type"] = "new_application"

        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
      end

      it "accepts recertification certification type" do
        valid_record["certification_type"] = "recertification"

        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
      end

      it "accepts valid date_of_birth when present" do
        valid_record["date_of_birth"] = "1990-05-15"

        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
      end

      it "accepts blank optional integer fields" do
        valid_record.delete("lookback_period")
        valid_record.delete("number_of_months_to_certify")
        valid_record.delete("due_period_days")
        valid_record.delete("work_hours")

        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
      end

      it "accepts blank optional date fields" do
        valid_record.delete("date_of_birth")

        result = validator.validate(valid_record)

        expect(result.success?).to be(true)
      end
    end

    context "with missing required fields (VAL_001)" do
      described_class::REQUIRED_FIELDS.each do |field|
        it "fails when #{field} is missing" do
          record = {
            "member_id" => "M12345",
            "case_number" => "C-001",
            "member_email" => "test@example.com",
            "certification_date" => "2025-01-15",
            "certification_type" => "new_application"
          }
          record.delete(field)

          result = validator.validate(record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
          expect(result.error_message).to include("Missing required fields")
          expect(result.error_message).to include(field)
        end
      end

      it "lists all missing fields in error message" do
        record = { "member_id" => "M12345" }

        result = validator.validate(record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
        expect(result.error_message).to include("case_number")
        expect(result.error_message).to include("member_email")
        expect(result.error_message).to include("certification_date")
        expect(result.error_message).to include("certification_type")
      end
    end

    context "with invalid date formats (VAL_002)" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      describe "certification_date validation" do
        it "fails with wrong format (MM/DD/YYYY)" do
          base_record["certification_date"] = "01/15/2025"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("certification_date")
          expect(result.error_message).to include("01/15/2025")
          expect(result.error_message).to include("YYYY-MM-DD")
        end

        it "fails with wrong format (DD-MM-YYYY)" do
          base_record["certification_date"] = "15-01-2025"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("certification_date")
        end

        it "fails with unparseable date (invalid month)" do
          base_record["certification_date"] = "2025-13-01"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("unparseable")
          expect(result.error_message).to include("2025-13-01")
        end

        it "fails with unparseable date (invalid day)" do
          base_record["certification_date"] = "2025-02-30"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("unparseable")
        end

        it "fails with text instead of date" do
          base_record["certification_date"] = "January 15, 2025"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
        end
      end

      describe "date_of_birth validation (optional field)" do
        it "fails with wrong format when present" do
          base_record["date_of_birth"] = "05/15/1990"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("date_of_birth")
          expect(result.error_message).to include("05/15/1990")
        end

        it "fails with unparseable date when present" do
          base_record["date_of_birth"] = "1990-13-45"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
          expect(result.error_message).to include("unparseable")
        end

        it "succeeds when date_of_birth is blank" do
          base_record["date_of_birth"] = ""

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end

        it "succeeds when date_of_birth is not present" do
          # date_of_birth not included in base_record
          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end
      end
    end

    context "with invalid email format (VAL_003)" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "fails with missing @ symbol" do
        base_record["member_email"] = "testexample.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
        expect(result.error_message).to include("member_email")
        expect(result.error_message).to include("testexample.com")
        expect(result.error_message).to include("user@example.com")
      end

      it "fails with missing domain" do
        base_record["member_email"] = "test@"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
        expect(result.error_message).to include("test@")
      end

      it "fails with missing local part" do
        base_record["member_email"] = "@example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
      end

      it "fails with spaces in email" do
        base_record["member_email"] = "test user@example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
        expect(result.error_message).to include("test user@example.com")
      end

      it "fails with invalid characters" do
        base_record["member_email"] = "test<>@example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
      end

      it "accepts valid email with subdomain" do
        base_record["member_email"] = "test@mail.example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end

      it "accepts valid email with plus addressing" do
        base_record["member_email"] = "test+tag@example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end

      it "accepts valid email with dots" do
        base_record["member_email"] = "first.last@example.com"

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end
    end

    context "with invalid certification type (VAL_004)" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "fails with invalid certification type" do
        base_record["certification_type"] = "renewal"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_TYPE)
        expect(result.error_message).to include("certification_type")
        expect(result.error_message).to include("renewal")
        expect(result.error_message).to include("new_application")
        expect(result.error_message).to include("recertification")
      end

      it "succeeds with empty string (skipped as blank)" do
        base_record["certification_type"] = ""

        result = validator.validate(base_record)

        # Empty string is not caught by required fields (key exists)
        # Certification type validation skips blank values
        # ActiveRecord validation will catch this later during save
        expect(result.success?).to be(true)
      end

      it "fails with wrong case" do
        base_record["certification_type"] = "NEW_APPLICATION"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_TYPE)
        expect(result.error_message).to include("NEW_APPLICATION")
      end

      it "fails with typo" do
        base_record["certification_type"] = "new_applicaton"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_TYPE)
      end
    end

    context "with invalid integer fields (VAL_005)" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      describe "lookback_period validation" do
        it "fails with non-numeric value" do
          base_record["lookback_period"] = "thirty"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
          expect(result.error_message).to include("lookback_period")
          expect(result.error_message).to include("thirty")
          expect(result.error_message).to include("positive integer")
        end

        it "fails with decimal value" do
          base_record["lookback_period"] = "30.5"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
          expect(result.error_message).to include("30.5")
        end

        it "fails with negative value" do
          base_record["lookback_period"] = "-30"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
        end

        it "succeeds when blank" do
          base_record["lookback_period"] = ""

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end

        it "succeeds when not present" do
          # lookback_period not included in base_record
          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end

        it "succeeds with valid integer" do
          base_record["lookback_period"] = "90"

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end
      end

      describe "number_of_months_to_certify validation" do
        it "fails with non-numeric value" do
          base_record["number_of_months_to_certify"] = "six"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
          expect(result.error_message).to include("number_of_months_to_certify")
          expect(result.error_message).to include("six")
        end

        it "succeeds with valid integer" do
          base_record["number_of_months_to_certify"] = "6"

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end
      end

      describe "due_period_days validation" do
        it "fails with non-numeric value" do
          base_record["due_period_days"] = "30 days"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
          expect(result.error_message).to include("due_period_days")
          expect(result.error_message).to include("30 days")
        end

        it "succeeds with valid integer" do
          base_record["due_period_days"] = "30"

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end
      end

      describe "work_hours validation" do
        it "fails with non-numeric value" do
          base_record["work_hours"] = "twenty"

          result = validator.validate(base_record)

          expect(result.success?).to be(false)
          expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_INTEGER)
          expect(result.error_message).to include("work_hours")
          expect(result.error_message).to include("twenty")
        end

        it "succeeds with valid integer" do
          base_record["work_hours"] = "20"

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end

        it "succeeds with zero" do
          base_record["work_hours"] = "0"

          result = validator.validate(base_record)

          expect(result.success?).to be(true)
        end
      end
    end

    context "with validation priority (fail-fast)" do
      it "returns required fields error before date format error" do
        record = {
          "member_id" => "M12345",
          "certification_date" => "invalid-date"
          # Missing required fields
        }

        result = validator.validate(record)

        expect(result.error_code).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
      end

      it "returns date format error before email format error" do
        record = {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "invalid-email",
          "certification_date" => "invalid-date",
          "certification_type" => "new_application"
        }

        result = validator.validate(record)

        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
      end

      it "returns email format error before certification type error" do
        record = {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "invalid-email",
          "certification_date" => "2025-01-15",
          "certification_type" => "invalid-type"
        }

        result = validator.validate(record)

        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_EMAIL)
      end

      it "returns certification type error before integer format error" do
        record = {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "invalid-type",
          "lookback_period" => "invalid"
        }

        result = validator.validate(record)

        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_TYPE)
      end
    end

    context "with edge cases" do
      let(:base_record) do
        {
          "member_id" => "M12345",
          "case_number" => "C-001",
          "member_email" => "test@example.com",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }
      end

      it "accepts record with all optional fields populated" do
        base_record.merge!(
          "first_name" => "Alice",
          "last_name" => "Smith",
          "date_of_birth" => "1990-05-15",
          "lookback_period" => "90",
          "number_of_months_to_certify" => "6",
          "due_period_days" => "30",
          "work_hours" => "20"
        )

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end

      it "accepts record with no optional fields" do
        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end

      it "accepts leap year date" do
        base_record["certification_date"] = "2024-02-29"

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end

      it "fails with non-leap year Feb 29" do
        base_record["certification_date"] = "2025-02-29"

        result = validator.validate(base_record)

        expect(result.success?).to be(false)
        expect(result.error_code).to eq(BatchUploadErrors::Validation::INVALID_DATE)
      end

      it "accepts very large integers" do
        base_record["work_hours"] = "999999"

        result = validator.validate(base_record)

        expect(result.success?).to be(true)
      end
    end

    describe "ValidationResult" do
      describe ".success" do
        it "creates success result" do
          result = described_class::ValidationResult.success

          expect(result.success?).to be(true)
          expect(result.error_code).to be_nil
          expect(result.error_message).to be_nil
        end
      end

      describe ".error" do
        it "creates error result with code and message" do
          result = described_class::ValidationResult.error("TEST_001", "Test error")

          expect(result.success?).to be(false)
          expect(result.error_code).to eq("TEST_001")
          expect(result.error_message).to eq("Test error")
        end
      end
    end
  end
end
