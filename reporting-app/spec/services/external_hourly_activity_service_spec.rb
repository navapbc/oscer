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

      it "stores the origin_hash it is given" do
        result = described_class.create_entry(**valid_params, origin_hash: "abc123")

        expect(result.origin_hash).to eq("abc123")
      end
    end

    context "with an existing identical entry" do
      before do
        create(:external_hourly_activity,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               hours: valid_params[:hours],
               period_start: valid_params[:period_start],
               period_end: valid_params[:period_end])
      end

      it "creates the entry, since duplicates are rejected by create_entries" do
        expect { described_class.create_entry(**valid_params) }
          .to change(ExternalHourlyActivity, :count).by(1)
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

    context "when a month's share rounds to zero" do
      let(:hours) { 1 }
      let(:period_start) { Date.new(2026, 1, 31) }
      let(:period_end) { Date.new(2026, 12, 31) }

      it "skips the month rather than failing the whole period" do
        results = described_class.create_entries(**valid_params)

        expect(results.map(&:period_start)).not_to include(period_start)
        expect(results.map(&:hours)).to all be > 0
        expect(results.sum(&:hours)).to eq hours
      end
    end

    context "with an origin_hash" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "stamps the same hash on every entry of the submission" do
        results = described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(results.size).to eq 3
        expect(results.map(&:origin_hash).uniq.size).to eq 1
        expect(results.first.origin_hash).to be_present
      end

      it "differs when the name differs" do
        first = described_class.create_entries(**valid_params, name: "Acme Corp")
        second = described_class.create_entries(**valid_params, name: "Other Corp")

        expect(second.first.origin_hash).not_to eq first.first.origin_hash
      end
    end

    context "with a duplicate submission" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      before { described_class.create_entries(**valid_params, name: "Acme Corp") }

      it "raises a validation error" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp") }
          .to raise_error(ActiveRecord::RecordInvalid, /Duplicate entry/)
      end

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp") rescue nil }
          .not_to change(ExternalHourlyActivity, :count)
      end

      it "ignores name casing and surrounding whitespace" do
        expect { described_class.create_entries(**valid_params, name: " acme corp ") }
          .to raise_error(ActiveRecord::RecordInvalid, /Duplicate entry/)
      end

      # The API sends a plain integer; the specs above derive hours from a date range, which is a Rational.
      it "ignores how the hours value is typed or scaled" do
        [ hours.to_i, hours.to_f, BigDecimal("#{hours.to_i}.00") ].each do |equivalent_hours|
          expect { described_class.create_entries(**valid_params.merge(hours: equivalent_hours), name: "Acme Corp") }
            .to raise_error(ActiveRecord::RecordInvalid, /Duplicate entry/)
        end
      end

      it "accepts the same activity reported under a different name" do
        expect { described_class.create_entries(**valid_params, name: "Other Corp") }
          .to change(ExternalHourlyActivity, :count).by(3)
      end

      it "accepts the same activity for a different member" do
        expect { described_class.create_entries(**valid_params.merge(member_id: "987654321"), name: "Acme Corp") }
          .to change(ExternalHourlyActivity, :count).by(3)
      end
    end

    context "with an unnamed duplicate submission" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      before { described_class.create_entries(**valid_params) }

      it "raises a validation error" do
        expect { described_class.create_entries(**valid_params) }
          .to raise_error(ActiveRecord::RecordInvalid, /Duplicate entry/)
      end
    end
  end

  describe ".duplicate_entry?" do
    let(:existing_entry) { create(:external_hourly_activity, :employment, origin_hash: "abc123") }

    it "returns true when an entry with the origin hash exists" do
      expect(described_class.duplicate_entry?(existing_entry.origin_hash)).to be true
    end

    it "returns false for an origin hash that has not been seen" do
      existing_entry

      expect(described_class.duplicate_entry?("def456")).to be false
    end

    it "returns false with no existing entries" do
      expect(described_class.duplicate_entry?("abc123")).to be false
    end
  end
end
