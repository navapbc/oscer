# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalHourlyActivityService do
  describe ".create_entry" do
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        hours: 40.0,
        period_start: Date.current.beginning_of_month,
        period_end: Date.current.end_of_month,
        source_type: ExternalHourlyActivity::SOURCE_TYPES[:api]
      }
    end

    context "with valid data" do
      it "creates an ExternalHourlyActivity" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(ExternalHourlyActivity)
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
        create(:external_hourly_activity,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               hours: valid_params[:hours],
               period_start: valid_params[:period_start],
               period_end: valid_params[:period_end])
      end

      it "returns conflict error" do
        expect { described_class.create_entry(**valid_params) }.to raise_error(/Duplicate entry/)
      end

      it "does not create a new entry" do
        expect {
          begin
            described_class.create_entry(**valid_params)
          rescue
          end
        }.not_to change(ExternalHourlyActivity, :count)
      end
    end

    context "with validation errors" do
      it "returns error for missing member_id" do
        expect { described_class.create_entry(**valid_params.merge(member_id: nil)) }.to raise_error(/Member/)
      end

      it "returns error for invalid category" do
        expect { described_class.create_entry(**valid_params.merge(category: "invalid")) }.to raise_error(/Category/)
      end

      it "returns error for zero hours" do
        expect { described_class.create_entry(**valid_params.merge(hours: 0)) }.to raise_error(/Hours/)
      end

      it "returns error for negative hours" do
        expect { described_class.create_entry(**valid_params.merge(hours: -10)) }.to raise_error(/Hours/)
      end

      it "returns error for invalid source_type" do
        expect { described_class.create_entry(**valid_params.merge(source_type: "invalid")) }.to raise_error(/Source type/)
      end
    end

    context "with batch_upload source" do
      it "creates entry with batch source_type and source_id" do
        result = described_class.create_entry(
          **valid_params,
          source_type: ExternalHourlyActivity::SOURCE_TYPES[:batch],
          source_id: "upload-456"
        )

        expect(result).to be_a(ExternalHourlyActivity)
        expect(result.source_type).to eq("batch_upload")
        expect(result.source_id).to eq("upload-456")
      end
    end
  end

  describe ".create_entries" do
    let(:hours) { period_end - period_start + 1 } # 1 hour per day
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        hours:,
        period_start:,
        period_end:,
        source_type: ExternalHourlyActivity::SOURCE_TYPES[:api]
      }
    end

    context "with 3 full months" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "has three months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 3
      end

      it "apportions hours by number of days in month" do
        described_class.create_entries(**valid_params).each do |result|
          days_in_month = result.period_end - result.period_start + 1
          expect(result.hours).to eq days_in_month
        end
      end
    end

    context "with partial months" do
      let(:days_in_start_month) { 10 }
      let(:days_in_end_month) { 15 }
      let(:period_start) { (3.months.ago.end_of_month - days_in_start_month.days + 1).to_date }
      let(:period_end) { (2.months.ago.end_of_month + days_in_end_month.days).to_date }

      it "has 3 months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 3
      end

      it "apportions hours by number of days in period in month" do
        results = described_class.create_entries(**valid_params)

        expect(results.first.hours).to eq days_in_start_month
        expect(results.last.hours).to eq days_in_end_month

        days_in_middle_month = results[1].period_end - results[1].period_start + 1
        expect(results[1].hours).to eq days_in_middle_month
      end
    end

    context "when spans year boundary" do
      let(:period_start) { 20.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "has twenty months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 20
      end

      it "apportions hours by number of days in month" do
        described_class.create_entries(**valid_params).each do |result|
          days_in_month = result.period_end - result.period_start + 1
          expect(result.hours).to eq days_in_month
        end
      end
    end

    context "when not 1 hour per day" do
      let(:days_in_start_month) { 10 }
      let(:days_in_end_month) { 18 }
      let(:hours) { (days_in_start_month + days_in_end_month) / 2 }
      let(:period_start) { (3.months.ago.end_of_month - days_in_start_month.days + 1).to_date }
      let(:period_end) { (3.months.ago.end_of_month + days_in_end_month.days).to_date }

      it "apportions hours by number of days in period in month" do
        results = described_class.create_entries(**valid_params)

        expect(results.first.hours).to eq days_in_start_month / 2
        expect(results.last.hours).to eq days_in_end_month / 2
      end
    end

    # The API supplies hours as a BigDecimal, which rarely divides evenly across months.
    context "when hours do not divide evenly" do
      let(:hours) { BigDecimal("100") }
      let(:period_start) { Date.new(2026, 5, 1) }
      let(:period_end) { Date.new(2026, 7, 31) }

      it "apportions the full total without rounding drift" do
        results = described_class.create_entries(**valid_params)

        expect(results.sum(&:hours)).to eq hours
      end

      it "keeps each entry within a hundredth of an hour of its exact share" do
        results = described_class.create_entries(**valid_params)
        total_days = period_end - period_start + 1

        results.each do |result|
          days = result.period_end - result.period_start + 1
          expect(result.hours).to be_within(0.01).of(days * hours / total_days)
        end
      end
    end

    context "with a source_id" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "sets it on every entry" do
        results = described_class.create_entries(**valid_params, source_id: "batch-123")

        expect(results.size).to be > 1
        expect(results.map(&:source_id)).to all eq "batch-123"
      end

      it "sets it on a single-month period" do
        results = described_class.create_entries(
          **valid_params.merge(period_end: period_start.end_of_month), source_id: "batch-123"
        )

        expect(results.map(&:source_id)).to eq [ "batch-123" ]
      end
    end

    # Malformed input must still be rejected by the model rather than failing in the
    # apportioning arithmetic.
    context "with blank hours" do
      let(:hours) { nil }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "raises a validation error" do
        expect { described_class.create_entries(**valid_params) }
          .to raise_error(ActiveRecord::RecordInvalid, /Hours/)
      end
    end

    context "when the period is reversed" do
      let(:hours) { BigDecimal("40") }
      let(:period_start) { 1.month.ago.end_of_month.to_date }
      let(:period_end) { 3.months.ago.beginning_of_month.to_date }

      it "raises a validation error" do
        expect { described_class.create_entries(**valid_params) }
          .to raise_error(ActiveRecord::RecordInvalid, /cannot be after end date/)
      end

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params) rescue nil }
          .not_to change(ExternalHourlyActivity, :count)
      end
    end
  end

  describe ".duplicate_entry?" do
    let(:existing_entry) { create(:external_hourly_activity, :employment) }

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
