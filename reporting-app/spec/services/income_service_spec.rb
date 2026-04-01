# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomeService do
  describe ".create_entry" do
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        gross_income: 580.00,
        period_start: Date.current.beginning_of_month,
        period_end: Date.current.end_of_month,
        source_type: Income::SOURCE_TYPES[:api]
      }
    end

    context "with valid data" do
      it "creates an Income" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(Income)
        expect(result).to be_persisted
        expect(result.member_id).to eq("123456789")
        expect(result.category).to eq("employment")
        expect(result.gross_income).to eq(580.00)
      end

      it "sets source_type correctly" do
        result = described_class.create_entry(**valid_params)

        expect(result.source_type).to eq("api")
      end

      it "sets optional source_id when provided" do
        result = described_class.create_entry(**valid_params, source_id: "batch-123")

        expect(result.source_id).to eq("batch-123")
      end

      it "merges employer into metadata when provided" do
        result = described_class.create_entry(**valid_params, employer: "Acme Corp", metadata: { "note" => "x" })

        expect(result.metadata).to eq({ "note" => "x", "employer" => "Acme Corp" })
      end

      it "defaults reported_at when omitted" do
        freeze_time do
          result = described_class.create_entry(**valid_params)

          expect(result.reported_at).to eq(Time.current)
        end
      end
    end

    context "with duplicate entry" do
      before do
        create(:income,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               gross_income: valid_params[:gross_income],
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
        }.not_to change(Income, :count)
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

      it "returns error for zero gross_income" do
        result = described_class.create_entry(**valid_params.merge(gross_income: 0))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Gross income")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for negative gross_income" do
        result = described_class.create_entry(**valid_params.merge(gross_income: -10))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Gross income")
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it "returns error for invalid source_type" do
        result = described_class.create_entry(**valid_params.merge(source_type: "invalid"))

        expect(result).to be_a(Hash)
        expect(result[:error]).to include("Source type")
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "with quarterly_wage_data source" do
      it "creates entry with quarterly_wage_data source_type" do
        result = described_class.create_entry(
          **valid_params,
          source_type: Income::SOURCE_TYPES[:quarterly_wage_data]
        )

        expect(result).to be_a(Income)
        expect(result.source_type).to eq("quarterly_wage_data")
      end
    end

    context "with batch_upload source" do
      it "creates entry with batch source_type and source_id" do
        result = described_class.create_entry(
          **valid_params,
          source_type: Income::SOURCE_TYPES[:batch_upload],
          source_id: "upload-456"
        )

        expect(result).to be_a(Income)
        expect(result.source_type).to eq("batch_upload")
        expect(result.source_id).to eq("upload-456")
      end
    end
  end

  describe ".duplicate_entry?" do
    let(:existing_entry) { create(:income, :employment) }

    context "with exact match" do
      it "returns true" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          gross_income: existing_entry.gross_income,
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
          gross_income: existing_entry.gross_income,
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
          gross_income: existing_entry.gross_income,
          period_start: existing_entry.period_start,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end
    end

    context "with different gross_income" do
      it "returns false" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          gross_income: existing_entry.gross_income + 1,
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
          gross_income: existing_entry.gross_income,
          period_start: existing_entry.period_start + 1.day,
          period_end: existing_entry.period_end
        )

        expect(result).to be false
      end

      it "returns false for different end date" do
        result = described_class.duplicate_entry?(
          member_id: existing_entry.member_id,
          category: existing_entry.category,
          gross_income: existing_entry.gross_income,
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
          gross_income: 100.0,
          period_start: Date.current,
          period_end: Date.current.end_of_month
        )

        expect(result).to be false
      end
    end
  end
end
