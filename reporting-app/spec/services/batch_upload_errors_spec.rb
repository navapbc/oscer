# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchUploadErrors do
  describe ".all_codes" do
    it "returns all error codes from all categories" do
      codes = described_class.all_codes

      expect(codes).to include("VAL_001", "VAL_002", "DUP_001", "DB_001", "UNK_001")
      expect(codes).to all(be_a(String))
    end
  end

  describe "error code uniqueness" do
    it "has unique error codes across all categories" do
      codes = described_class.all_codes

      expect(codes.uniq.size).to eq(codes.size)
    end
  end

  describe "error code format" do
    it "follows the CATEGORY_NUMBER pattern" do
      codes = described_class.all_codes

      expect(codes).to all(match(/\A[A-Z]{2,3}_\d{3}\z/))
    end
  end

  describe "category modules" do
    it "has all documented categories" do
      expect(described_class.constants).to include(
        :Validation,
        :Duplicate,
        :Database,
        :Storage,
        :Unknown
      )
    end
  end
end
