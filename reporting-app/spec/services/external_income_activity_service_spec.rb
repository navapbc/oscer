# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalIncomeActivityService do
  describe ".create_entry" do
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        gross_income: 580.00,
        period_start: Date.current.beginning_of_month,
        period_end: Date.current.end_of_month,
        source_type: ExternalIncomeActivity::SOURCE_TYPES[:api]
      }
    end

    context "with valid data" do
      it "creates an ExternalIncomeActivity" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(ExternalIncomeActivity)
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

      it "stores the origin_hash it is given" do
        result = described_class.create_entry(**valid_params, origin_hash: "abc123")

        expect(result.origin_hash).to eq("abc123")
      end

      it "stores the reported name alongside the employer metadata" do
        result = described_class.create_entry(**valid_params, name: "Acme Corp", employer: "Acme Payroll")

        expect(result.name).to eq("Acme Corp")
        expect(result.metadata).to eq({ "employer" => "Acme Payroll" })
      end

      it "defaults reported_at when omitted" do
        freeze_time do
          result = described_class.create_entry(**valid_params)

          expect(result.reported_at).to eq(Time.current)
        end
      end

      it "logs created event" do
        result = described_class.create_entry(**valid_params)
        log_count = Strata::AuditLine.where(subject: result, actor_type: described_class.name, action: 'external_income_activity.create', data: result.attributes).count
        expect(log_count).to eq 1
      end
    end

    context "when the member has an open certification case" do
      let(:certification) { create(:certification) }
      let(:kase) { create(:certification_case, certification: certification) }

      before do
        allow(Strata::EventManager).to receive(:publish)
        allow(NotificationService).to receive(:send_email_notification)
      end

      it "persists an automated income determination after save" do
        lookback = certification.certification_requirements.continuous_lookback_period
        period_start = lookback.start.to_date
        period_end = lookback.start.to_date.end_of_month

        expect(kase).to be_open

        expect {
          described_class.create_entry(
            member_id: certification.member_id,
            category: "employment",
            gross_income: 600,
            period_start: period_start,
            period_end: period_end,
            source_type: ExternalIncomeActivity::SOURCE_TYPES[:api]
          )
        }.to change { Determination.where(subject_id: certification.id).count }.by(1)

        determination = Determination.where(subject_id: certification.id).order(created_at: :desc).first
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("income_reported_compliant")
        expect(kase.reload).to be_closed
      end

      it "skips recalculation when recalculate_income_compliance is false" do
        lookback = certification.certification_requirements.continuous_lookback_period
        period_start = lookback.start.to_date
        period_end = lookback.start.to_date.end_of_month

        expect {
          described_class.create_entry(
            member_id: certification.member_id,
            category: "employment",
            gross_income: 600,
            period_start: period_start,
            period_end: period_end,
            source_type: ExternalIncomeActivity::SOURCE_TYPES[:api],
            recalculate_income_compliance: false
          )
        }.not_to change { Determination.where(subject_id: certification.id).count }
      end
    end

    context "when the member has no open certification case" do
      before do
        allow(Strata::EventManager).to receive(:publish)
        allow(NotificationService).to receive(:send_email_notification)
      end

      it "creates income without running income compliance determination" do
        expect {
          described_class.create_entry(**valid_params)
        }.not_to change(Determination, :count)
      end
    end

    context "with an existing identical entry" do
      before do
        create(:external_income_activity,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               gross_income: valid_params[:gross_income],
               period_start: valid_params[:period_start],
               period_end: valid_params[:period_end])
      end

      it "creates the entry, since duplicates are rejected by create_entries" do
        expect { described_class.create_entry(**valid_params) }
          .to change(ExternalIncomeActivity, :count).by(1)
      end
    end

    context "with validation errors" do
      it "returns error for missing member_id" do
        expect { described_class.create_entry(**valid_params.merge(member_id: nil)) }.to raise_error(/Member/)
      end

      it "returns error for invalid category" do
        expect { described_class.create_entry(**valid_params.merge(category: "invalid")) }.to raise_error(/Category/)
      end

      it "returns error for zero gross_income" do
        expect { described_class.create_entry(**valid_params.merge(gross_income: 0)) }.to raise_error(/Gross income/)
      end

      it "returns error for negative gross_income" do
        expect { described_class.create_entry(**valid_params.merge(gross_income: -10)) }.to raise_error(/Gross income/)
      end

      it "returns error for invalid source_type" do
        expect { described_class.create_entry(**valid_params.merge(source_type: "invalid")) }.to raise_error(/Source type/)
      end
    end
  end

  describe "duplicate_entry? (private)" do
    let(:existing_entry) { create(:external_income_activity, :employment, origin_hash: "abc123") }

    def duplicate_entry?(origin_hash)
      described_class.send(:duplicate_entry?, origin_hash)
    end

    it "returns true when an entry with the origin hash exists" do
      expect(duplicate_entry?(existing_entry.origin_hash)).to be true
    end

    it "returns false for an origin hash that has not been seen" do
      existing_entry

      expect(duplicate_entry?("def456")).to be false
    end

    it "returns false with no existing entries" do
      expect(duplicate_entry?("abc123")).to be false
    end

    it "returns false for a blank origin hash, so unfingerprinted entries never match" do
      create(:external_income_activity, :employment, origin_hash: nil)

      expect(duplicate_entry?(nil)).to be false
    end
  end

  describe ".create_entries" do
    let(:gross_income) { period_end - period_start + 1 } # 1 dollar per day
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        gross_income:,
        period_start:,
        period_end:,
        source_type: ExternalIncomeActivity::SOURCE_TYPES[:api]
      }
    end

    context "with 3 full months" do
      let(:gross_income) { 300 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "has three months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 3
      end

      it "apportions hours equally by month" do
        described_class.create_entries(**valid_params).each do |result|
          expect(result.gross_income).to eq 100
        end
      end
    end

    context "with 3 full months income not divisible by 3" do
      let(:gross_income) { 301.to_f }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "cumulative adds up to gross income" do
        cumulative = described_class.create_entries(**valid_params).sum(&:gross_income)
        expect(cumulative).to eq gross_income
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

      it "apportions gross_income by number of days in period in month" do
        results = described_class.create_entries(**valid_params)

        expect(results.first.gross_income).to eq days_in_start_month
        expect(results.last.gross_income).to eq days_in_end_month

        days_in_middle_month = results[1].period_end - results[1].period_start + 1
        expect(results[1].gross_income).to eq days_in_middle_month
      end
    end

    context "when spans year boundary with full months" do
      let(:gross_income) { 20000 }
      let(:period_start) { 20.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "has twenty months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 20
      end

      it "apportions gross_income by number of days in month" do
        described_class.create_entries(**valid_params).each do |result|
          expect(result.gross_income).to eq 1000
        end
      end
    end

    context "when spans year boundary with partial month" do
      let(:period_start) { 20.months.ago.beginning_of_month.to_date + 1.day }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "has twenty months" do
        results = described_class.create_entries(**valid_params)

        expect(results.size).to eq 20
      end

      it "apportions gross_income by number of days in month" do
        described_class.create_entries(**valid_params).each do |result|
          days_in_month = result.period_end - result.period_start + 1
          expect(result.gross_income).to eq days_in_month
        end
      end
    end

    context "when not 1 dollar per day" do
      let(:days_in_start_month) { 10 }
      let(:days_in_end_month) { 18 }
      let(:gross_income) { (days_in_start_month + days_in_end_month) / 2 }
      let(:period_start) { (3.months.ago.end_of_month - days_in_start_month.days + 1).to_date }
      let(:period_end) { (3.months.ago.end_of_month + days_in_end_month.days).to_date }

      it "apportions gross_income by number of days in period in month" do
        results = described_class.create_entries(**valid_params)

        expect(results.first.gross_income).to eq days_in_start_month / 2
        expect(results.last.gross_income).to eq days_in_end_month / 2
      end
    end

    context "when gross_income do not divide evenly" do
      let(:gross_income) { BigDecimal("100") }
      let(:period_start) { Date.new(2026, 5, 2) }
      let(:period_end) { Date.new(2026, 7, 31) }

      it "apportions the full total without rounding drift" do
        results = described_class.create_entries(**valid_params)

        expect(results.sum(&:gross_income)).to eq gross_income
      end

      it "keeps each entry within a hundredth of an hour of its exact share" do
        results = described_class.create_entries(**valid_params)
        total_days = period_end - period_start + 1

        results.each do |result|
          days = result.period_end - result.period_start + 1
          expect(result.gross_income).to be_within(0.01).of(days * gross_income / total_days)
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

    context "with blank gross_income" do
      let(:gross_income) { nil }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "raises a validation error" do
        expect { described_class.create_entries(**valid_params) }
          .to raise_error(ActiveRecord::RecordInvalid, /Gross income/)
      end
    end

    context "when the period is reversed" do
      let(:gross_income) { BigDecimal("40") }
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
      let(:gross_income) { BigDecimal("0.05") }
      let(:period_start) { Date.new(2026, 1, 31) }
      let(:period_end) { Date.new(2026, 12, 31) }

      it "skips the month rather than failing the whole period" do
        results = described_class.create_entries(**valid_params)

        expect(results.map(&:period_start)).not_to include(period_start)
        expect(results.map(&:gross_income)).to all be > 0
        expect(results.sum(&:gross_income)).to eq gross_income
      end
    end

    context "when the member has an open certification case" do
      let(:certification) { create(:certification) }
      let(:gross_income) { 3000 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      before do
        create(:certification_case, certification: certification)
        allow(IncomeComplianceDeterminationService).to receive(:calculate)
      end

      it "recalculates income compliance once for the whole period, not once per entry" do
        results = described_class.create_entries(**valid_params.merge(member_id: certification.member_id))

        expect(results.size).to eq 3
        expect(IncomeComplianceDeterminationService).to have_received(:calculate).once
      end

      it "skips recalculation when recalculate_income_compliance is false" do
        described_class.create_entries(
          **valid_params.merge(member_id: certification.member_id, recalculate_income_compliance: false)
        )

        expect(IncomeComplianceDeterminationService).not_to have_received(:calculate)
      end
    end

    context "with a name" do
      let(:gross_income) { 300 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "stores it on every entry of the submission" do
        results = described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(results.size).to eq 3
        expect(results.map(&:name)).to all eq "Acme Corp"
      end
    end

    context "with an origin_hash" do
      let(:gross_income) { 300 }
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
      let(:gross_income) { 300 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      before do
        allow(Rails.logger).to receive(:warn)
        described_class.create_entries(**valid_params, name: "Acme Corp", employer: "Acme Payroll")
      end

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp") }
          .not_to change(ExternalIncomeActivity, :count)
      end

      it "returns no entries" do
        expect(described_class.create_entries(**valid_params, name: "Acme Corp")).to eq []
      end

      it "logs the duplicate" do
        described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(Rails.logger).to have_received(:warn).with(/skipped duplicate submission/)
      end

      it "ignores the employer, which is metadata rather than identity" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp", employer: "Other Payroll") }
          .not_to change(ExternalIncomeActivity, :count)
      end

      it "accepts the same income reported under a different name" do
        expect { described_class.create_entries(**valid_params, name: "Other Corp") }
          .to change(ExternalIncomeActivity, :count).by(3)
      end

      it "accepts the same income for a different member" do
        expect { described_class.create_entries(**valid_params.merge(member_id: "987654321"), name: "Acme Corp") }
          .to change(ExternalIncomeActivity, :count).by(3)
      end

      it "recalculates compliance only for the submission that created entries" do
        certification = create(:certification)
        create(:certification_case, certification: certification)
        allow(IncomeComplianceDeterminationService).to receive(:calculate)
        member_params = valid_params.merge(member_id: certification.member_id, name: "Acme Corp")
        described_class.create_entries(**member_params)

        described_class.create_entries(**member_params)

        expect(IncomeComplianceDeterminationService).to have_received(:calculate).once
      end
    end

    context "with an unnamed duplicate submission" do
      let(:gross_income) { 300 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      before { described_class.create_entries(**valid_params) }

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params) }
          .not_to change(ExternalIncomeActivity, :count)
      end

      it "treats a blank name as no name" do
        expect { described_class.create_entries(**valid_params, name: "  ") }
          .not_to change(ExternalIncomeActivity, :count)
      end
    end

    context "with a duplicate household submission" do
      let(:gross_income) { 300 }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }
      let(:household_params) do
        valid_params.merge(
          category: ExternalIncomeActivity::CATEGORY_HOUSEHOLD,
          name: "Elizabeth Doe",
          identity: [ "000000002", Date.new(1979, 9, 1) ]
        )
      end

      before do
        allow(Rails.logger).to receive(:warn)
        described_class.create_entries(**household_params)
      end

      it "creates no entries for the same household member" do
        expect { described_class.create_entries(**household_params) }
          .not_to change(ExternalIncomeActivity, :count)
      end

      it "accepts the same income from another household member" do
        expect {
          described_class.create_entries(
            **household_params.merge(name: "Richard Doe", identity: [ "000000003", Date.new(1983, 10, 2) ])
          )
        }.to change(ExternalIncomeActivity, :count).by(3)
      end

      it "tells household members who share a name apart by tax ID and date of birth" do
        expect {
          described_class.create_entries(**household_params.merge(identity: [ "000000003", Date.new(1983, 10, 2) ]))
        }.to change(ExternalIncomeActivity, :count).by(3)
      end

      it "accepts a different income from the same household member" do
        expect { described_class.create_entries(**household_params.merge(gross_income: 450)) }
          .to change(ExternalIncomeActivity, :count).by(3)
      end

      it "accepts income for a different period from the same household member" do
        expect {
          described_class.create_entries(
            **household_params.merge(period_start: 6.months.ago.beginning_of_month.to_date,
                                     period_end: 4.months.ago.end_of_month.to_date)
          )
        }.to change(ExternalIncomeActivity, :count).by(3)
      end
    end
  end
end
