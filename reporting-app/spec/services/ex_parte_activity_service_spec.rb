# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExParteActivityService do
  describe ".create_entry" do
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        hours: 40.0,
        period_start: Date.current.beginning_of_month,
        period_end: Date.current.end_of_month,
        source_type: ExParteActivity::SOURCE_TYPES[:api]
      }
    end

    context "with valid data" do
      it "creates an ExParteActivity" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(ExParteActivity)
        expect(result).to be_persisted
        expect(result.member_id).to eq("123456789")
        expect(result.category).to eq("employment")
        expect(result.hours).to eq(40.0)
      end

      it "sets source_type correctly" do
        result = described_class.create_entry(**valid_params)

        expect(result.source_type).to eq("api")
      end

      it "sets optional source_id when provided" do
        result = described_class.create_entry(**valid_params, source_id: "batch-123")

        expect(result.source_id).to eq("batch-123")
      end
    end

    context "with duplicate entry" do
      before do
        create(:ex_parte_activity,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               hours: valid_params[:hours],
               period_start: valid_params[:period_start],
               period_end: valid_params[:period_end])
      end

      it "returns conflict error" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(Hash)
        expect(result[:error]).to eq("Duplicate entry")
        expect(result[:status]).to eq(:conflict)
      end

      it "does not create a new entry" do
        expect {
          described_class.create_entry(**valid_params)
        }.not_to change(ExParteActivity, :count)
      end
    end

    context "with validation errors" do
      it "returns error for missing member_id" do
        result = described_class.create_entry(**valid_params.merge(member_id: nil))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Member")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for invalid category" do
        result = described_class.create_entry(**valid_params.merge(category: "invalid"))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Category")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for zero hours" do
        result = described_class.create_entry(**valid_params.merge(hours: 0))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Hours")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for negative hours" do
        result = described_class.create_entry(**valid_params.merge(hours: -10))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Hours")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for invalid source_type" do
        result = described_class.create_entry(**valid_params.merge(source_type: "invalid"))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Source type")
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "with batch_upload source" do
      it "creates entry with batch source_type and source_id" do
        result = described_class.create_entry(
          **valid_params,
          source_type: ExParteActivity::SOURCE_TYPES[:batch],
          source_id: "upload-456"
        )

        expect(result).to be_a(ExParteActivity)
        expect(result.source_type).to eq("batch_upload")
        expect(result.source_id).to eq("upload-456")
      end
    end
  end

  describe ".duplicate_entry?" do
    let(:existing_entry) { create(:ex_parte_activity, :employment) }

    context "with exact match" do
      it "returns true" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          hours: existing_entry.hours,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end
        )

        expect(result).to be true
      end
    end

    context "with different member_id" do
      it "returns false" do
        result = described_class.duplicate_entry?(
          member_id: "different-member",
          category: existing_entry.category,
          hours: existing_entry.hours,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end
    end

    context "with different category" do
      it "returns false" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: "education",
          hours: existing_entry.hours,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end
    end

    context "with different hours" do
      it "returns false" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          hours: existing_entry.hours + 10,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end
    end

    context "with different period" do
      it "returns false for different start date" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          hours: existing_entry.hours,
          period_start: existing_entry.period_start + 1.day,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end

      it "returns false for different end date" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          hours: existing_entry.hours,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end - 1.day
        )

        expect(result).to be false
      end
    end

    context "with no existing entries" do
      it "returns false" do
        result = described_class.duplicate_entry?(
          member_id: "new-member",
          category: "employment",
          hours: 40.0,
          period_start: Date.current,
          period_end: Date.current.end_of_month
        )

        expect(result).to be false
      end
    end
  end
end
