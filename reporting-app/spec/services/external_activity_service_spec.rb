# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalActivityService do
  describe ".create_entry" do
    let(:valid_params) do
      {
        member_id: "123456789",
        category: "employment",
        hours: 40.0,
        period_start: Date.current.beginning_of_month,
        period_end: Date.current.end_of_month,
        source_type: ExternalActivity::SOURCE_TYPES[:api]
      }
    end

    context "with valid data" do
      it "creates an hours-only ExternalActivity" do
        result = described_class.create_entry(**valid_params)

        expect(result).to be_a(ExternalActivity)
        expect(result).to be_persisted
        expect(result.member_id).to eq("123456789")
        expect(result.category).to eq("employment")
        expect(result.hours).to eq(40.0)
        expect(result.gross_income).to be_nil
      end

      it "creates an income-only ExternalActivity" do
        result = described_class.create_entry(**valid_params.merge(hours: nil, gross_income: 580.00))

        expect(result.hours).to be_nil
        expect(result.gross_income).to eq(580.00)
      end

      it "creates an ExternalActivity carrying both hours and income" do
        result = described_class.create_entry(**valid_params.merge(gross_income: 580.00))

        expect(result.hours).to eq(40.0)
        expect(result.gross_income).to eq(580.00)
      end

      it "sets source_type correctly" do
        expect(described_class.create_entry(**valid_params).source_type).to eq("api")
      end

      it "sets optional source_id when provided" do
        expect(described_class.create_entry(**valid_params, source_id: "batch-123").source_id).to eq("batch-123")
      end

      it "stores the origin_hash it is given" do
        expect(described_class.create_entry(**valid_params, origin_hash: "abc123").origin_hash).to eq("abc123")
      end

      it "stores the reported name" do
        expect(described_class.create_entry(**valid_params, name: "Acme Corp").name).to eq("Acme Corp")
      end

      it "merges employer into metadata when provided" do
        result = described_class.create_entry(**valid_params, employer: "Acme Corp", metadata: { "note" => "x" })

        expect(result.metadata).to eq({ "note" => "x", "employer" => "Acme Corp" })
      end

      it "stores the reported name alongside the employer metadata" do
        result = described_class.create_entry(**valid_params, name: "Acme Corp", employer: "Acme Payroll")

        expect(result.name).to eq("Acme Corp")
        expect(result.metadata).to eq({ "employer" => "Acme Payroll" })
      end

      # Hours rows previously had no reported_at column at all; every row carries one now.
      it "defaults reported_at when omitted" do
        freeze_time do
          expect(described_class.create_entry(**valid_params).reported_at).to eq(Time.current)
        end
      end

      it "logs a created event for an hours-only row" do
        result = described_class.create_entry(**valid_params)

        log_count = Strata::AuditLine.where(subject: result, actor_type: described_class.name,
                                            action: "external_activity.create", data: result.attributes).count
        expect(log_count).to eq 1
      end

      it "logs the same action for an income-only row" do
        result = described_class.create_entry(**valid_params.merge(hours: nil, gross_income: 580.00))

        log_count = Strata::AuditLine.where(subject: result, actor_type: described_class.name,
                                            action: "external_activity.create").count
        expect(log_count).to eq 1
      end
    end

    context "with an existing identical entry" do
      before do
        create(:external_activity, :with_hours,
               member_id: valid_params[:member_id],
               category: valid_params[:category],
               hours: valid_params[:hours],
               period_start: valid_params[:period_start],
               period_end: valid_params[:period_end])
      end

      it "creates the entry, since duplicates are rejected by create_entries" do
        expect { described_class.create_entry(**valid_params) }
          .to change(ExternalActivity, :count).by(1)
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

      it "returns error for zero gross_income" do
        expect { described_class.create_entry(**valid_params.merge(hours: nil, gross_income: 0)) }
          .to raise_error(/Gross income/)
      end

      it "returns error when neither hours nor gross_income is given" do
        expect { described_class.create_entry(**valid_params.merge(hours: nil)) }
          .to raise_error(/must report hours, gross income, or both/)
      end

      it "returns error for invalid source_type" do
        expect { described_class.create_entry(**valid_params.merge(source_type: "invalid")) }
          .to raise_error(/Source type/)
      end

      it "returns error for hours exceeding the reported period" do
        expect {
          described_class.create_entry(
            **valid_params.merge(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 7), hours: 500)
          )
        }.to raise_error(/cannot exceed 168 hours/)
      end
    end

    context "with batch_upload source" do
      it "creates entry with batch source_type and source_id" do
        result = described_class.create_entry(
          **valid_params, source_type: ExternalActivity::SOURCE_TYPES[:batch], source_id: "upload-456"
        )

        expect(result.source_type).to eq("batch_upload")
        expect(result.source_id).to eq("upload-456")
      end
    end
  end

  describe ".create_entries" do
    let(:base_params) do
      {
        member_id: "123456789",
        category: "employment",
        period_start:,
        period_end:,
        source_type: ExternalActivity::SOURCE_TYPES[:api]
      }
    end

    # --- Hours: always apportioned by days ---

    describe "an hours-only submission" do
      let(:hours) { period_end - period_start + 1 } # 1 hour per day
      let(:valid_params) { base_params.merge(hours:) }

      context "with 3 full months" do
        let(:period_start) { 3.months.ago.beginning_of_month.to_date }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "has three months" do
          expect(described_class.create_entries(**valid_params).size).to eq 3
        end

        it "apportions hours by number of days in month" do
          described_class.create_entries(**valid_params).each do |result|
            expect(result.hours).to eq(result.period_end - result.period_start + 1)
          end
        end

        it "leaves gross_income unset on every entry" do
          expect(described_class.create_entries(**valid_params).map(&:gross_income)).to all be_nil
        end
      end

      context "with partial months" do
        let(:days_in_start_month) { 10 }
        let(:days_in_end_month) { 15 }
        let(:period_start) { (3.months.ago.end_of_month - days_in_start_month.days + 1).to_date }
        let(:period_end) { (2.months.ago.end_of_month + days_in_end_month.days).to_date }

        it "has 3 months" do
          expect(described_class.create_entries(**valid_params).size).to eq 3
        end

        it "apportions hours by number of days in period in month" do
          results = described_class.create_entries(**valid_params)

          expect(results.first.hours).to eq days_in_start_month
          expect(results.last.hours).to eq days_in_end_month
          expect(results[1].hours).to eq(results[1].period_end - results[1].period_start + 1)
        end
      end

      context "when spans year boundary" do
        let(:period_start) { 20.months.ago.beginning_of_month.to_date }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "has twenty months" do
          expect(described_class.create_entries(**valid_params).size).to eq 20
        end

        it "apportions hours by number of days in month" do
          described_class.create_entries(**valid_params).each do |result|
            expect(result.hours).to eq(result.period_end - result.period_start + 1)
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
          expect(described_class.create_entries(**valid_params).sum(&:hours)).to eq hours
        end

        it "keeps each entry within a hundredth of an hour of its exact share" do
          total_days = period_end - period_start + 1

          described_class.create_entries(**valid_params).each do |result|
            days = result.period_end - result.period_start + 1
            expect(result.hours).to be_within(0.01).of(days * hours / total_days)
          end
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
    end

    # --- Income: evenly for whole months, by days otherwise ---

    describe "an income-only submission" do
      let(:gross_income) { period_end - period_start + 1 } # 1 dollar per day
      let(:valid_params) { base_params.merge(gross_income:) }

      context "with 3 full months" do
        let(:gross_income) { 300 }
        let(:period_start) { 3.months.ago.beginning_of_month.to_date }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "has three months" do
          expect(described_class.create_entries(**valid_params).size).to eq 3
        end

        it "apportions income equally by month" do
          described_class.create_entries(**valid_params).each do |result|
            expect(result.gross_income).to eq 100
          end
        end

        it "leaves hours unset on every entry" do
          expect(described_class.create_entries(**valid_params).map(&:hours)).to all be_nil
        end
      end

      context "with 3 full months income not divisible by 3" do
        let(:gross_income) { 301.to_f }
        let(:period_start) { 3.months.ago.beginning_of_month.to_date }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "cumulative adds up to gross income" do
          expect(described_class.create_entries(**valid_params).sum(&:gross_income)).to eq gross_income
        end
      end

      context "with partial months" do
        let(:days_in_start_month) { 10 }
        let(:days_in_end_month) { 15 }
        let(:period_start) { (3.months.ago.end_of_month - days_in_start_month.days + 1).to_date }
        let(:period_end) { (2.months.ago.end_of_month + days_in_end_month.days).to_date }

        it "apportions gross_income by number of days in period in month" do
          results = described_class.create_entries(**valid_params)

          expect(results.size).to eq 3
          expect(results.first.gross_income).to eq days_in_start_month
          expect(results.last.gross_income).to eq days_in_end_month
        end
      end

      context "when spans year boundary with full months" do
        let(:gross_income) { 20_000 }
        let(:period_start) { 20.months.ago.beginning_of_month.to_date }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "apportions gross_income equally by month" do
          results = described_class.create_entries(**valid_params)

          expect(results.size).to eq 20
          expect(results.map(&:gross_income)).to all eq 1_000
        end
      end

      context "when spans year boundary with partial month" do
        let(:period_start) { 20.months.ago.beginning_of_month.to_date + 1.day }
        let(:period_end) { 1.month.ago.end_of_month.to_date }

        it "apportions gross_income by number of days in month" do
          results = described_class.create_entries(**valid_params)

          expect(results.size).to eq 20
          results.each do |result|
            expect(result.gross_income).to eq(result.period_end - result.period_start + 1)
          end
        end
      end

      context "when gross_income does not divide evenly" do
        let(:gross_income) { BigDecimal("100") }
        let(:period_start) { Date.new(2026, 5, 2) }
        let(:period_end) { Date.new(2026, 7, 31) }

        it "apportions the full total without rounding drift" do
          expect(described_class.create_entries(**valid_params).sum(&:gross_income)).to eq gross_income
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
    end

    # --- Combined: hours present, so both columns apportion by days ---

    describe "a submission carrying both hours and income" do
      let(:valid_params) { base_params.merge(hours:, gross_income:) }

      context "with 3 full months" do
        let(:hours) { 300 }
        let(:gross_income) { 3_000 }
        let(:period_start) { Date.new(2026, 1, 1) }
        let(:period_end) { Date.new(2026, 3, 31) }

        it "creates one entry per month carrying both values" do
          results = described_class.create_entries(**valid_params)

          expect(results.size).to eq 3
          expect(results.map(&:hours)).to all be_present
          expect(results.map(&:gross_income)).to all be_present
        end

        it "apportions both totals in full" do
          results = described_class.create_entries(**valid_params)

          expect(results.sum(&:hours)).to eq hours
          expect(results.sum(&:gross_income)).to eq gross_income
        end

        # Whole months would normally split income evenly; the presence of hours makes both
        # values apportion by days so the halves of one activity stay aligned.
        it "apportions income by days rather than evenly, because hours are present" do
          results = described_class.create_entries(**valid_params)
          total_days = period_end - period_start + 1

          results.each do |result|
            days = result.period_end - result.period_start + 1
            expect(result.gross_income).to be_within(0.01).of(days * gross_income / total_days)
          end
        end
      end

      context "when one value's share rounds to zero in a month" do
        let(:hours) { 300 }
        let(:gross_income) { BigDecimal("0.05") }
        let(:period_start) { Date.new(2026, 1, 31) }
        let(:period_end) { Date.new(2026, 12, 31) }

        # Apportioning the two values independently and zipping them would misalign the months.
        it "keeps every month the hours need and leaves income unset where its share vanished" do
          results = described_class.create_entries(**valid_params)

          expect(results.map(&:hours)).to all be_present
          expect(results.map(&:period_start)).to include(period_start)
          expect(results.map(&:gross_income).compact).to all be > 0
        end

        it "still apportions both totals in full" do
          results = described_class.create_entries(**valid_params)

          expect(results.sum(&:hours)).to eq hours
          expect(results.filter_map(&:gross_income).sum).to eq gross_income
        end
      end

      context "with a single month" do
        let(:hours) { 40 }
        let(:gross_income) { 620 }
        let(:period_start) { Date.new(2026, 1, 1) }
        let(:period_end) { Date.new(2026, 1, 31) }

        it "creates one entry with both values" do
          results = described_class.create_entries(**valid_params)

          expect(results.size).to eq 1
          expect(results.first.hours).to eq 40
          expect(results.first.gross_income).to eq 620
        end
      end
    end

    # --- Shared behavior ---

    describe "submission-wide attributes" do
      let(:valid_params) { base_params.merge(hours: 300) }
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "sets source_id on every entry" do
        results = described_class.create_entries(**valid_params, source_id: "batch-123")

        expect(results.size).to be > 1
        expect(results.map(&:source_id)).to all eq "batch-123"
      end

      it "sets source_id on a single-month period" do
        results = described_class.create_entries(
          **valid_params.merge(period_end: period_start.end_of_month), source_id: "batch-123"
        )

        expect(results.map(&:source_id)).to eq [ "batch-123" ]
      end

      it "stores the name on every entry of the submission" do
        results = described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(results.size).to eq 3
        expect(results.map(&:name)).to all eq "Acme Corp"
      end

      it "stamps the same origin_hash on every entry of the submission" do
        results = described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(results.map(&:origin_hash).uniq.size).to eq 1
        expect(results.first.origin_hash).to be_present
      end
    end

    describe "invalid submissions" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }

      it "raises when neither hours nor gross_income is given" do
        expect { described_class.create_entries(**base_params) }
          .to raise_error(ActiveRecord::RecordInvalid, /must report hours, gross income, or both/)
      end

      context "when the period is reversed" do
        let(:period_start) { 1.month.ago.end_of_month.to_date }
        let(:period_end) { 3.months.ago.beginning_of_month.to_date }

        it "raises a validation error" do
          expect { described_class.create_entries(**base_params.merge(hours: BigDecimal("40"))) }
            .to raise_error(ActiveRecord::RecordInvalid, /cannot be after end date/)
        end

        it "creates no entries" do
          expect {
            begin
              described_class.create_entries(**base_params.merge(hours: BigDecimal("40")))
            rescue ActiveRecord::RecordInvalid
              nil
            end
          }.not_to change(ExternalActivity, :count)
        end
      end
    end

    describe "duplicate detection" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }
      let(:valid_params) { base_params.merge(hours: 300) }

      before do
        allow(Rails.logger).to receive(:warn)
        described_class.create_entries(**valid_params, name: "Acme Corp")
      end

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp") }
          .not_to change(ExternalActivity, :count)
      end

      it "returns no entries" do
        expect(described_class.create_entries(**valid_params, name: "Acme Corp")).to eq []
      end

      it "logs the duplicate" do
        described_class.create_entries(**valid_params, name: "Acme Corp")

        expect(Rails.logger).to have_received(:warn).with(/skipped duplicate submission/)
      end

      it "ignores name casing and surrounding whitespace" do
        expect { described_class.create_entries(**valid_params, name: " acme corp ") }
          .not_to change(ExternalActivity, :count)
      end

      it "ignores how the value is typed or scaled" do
        [ 300, 300.0, BigDecimal("300.00") ].each do |equivalent|
          expect { described_class.create_entries(**valid_params.merge(hours: equivalent), name: "Acme Corp") }
            .not_to change(ExternalActivity, :count)
        end
      end

      it "ignores the employer, which is metadata rather than identity" do
        expect { described_class.create_entries(**valid_params, name: "Acme Corp", employer: "Other Payroll") }
          .not_to change(ExternalActivity, :count)
      end

      it "accepts the same activity reported under a different name" do
        expect { described_class.create_entries(**valid_params, name: "Other Corp") }
          .to change(ExternalActivity, :count).by(3)
      end

      it "accepts the same activity for a different member" do
        expect { described_class.create_entries(**valid_params.merge(member_id: "987654321"), name: "Acme Corp") }
          .to change(ExternalActivity, :count).by(3)
      end

      # The fingerprint covers both values, so the three shapes can never collide.
      it "treats the same total as income rather than hours as a different submission" do
        expect {
          described_class.create_entries(**base_params.merge(gross_income: 300), name: "Acme Corp")
        }.to change(ExternalActivity, :count).by(3)
      end

      it "treats adding income to an existing hours submission as a different submission" do
        expect {
          described_class.create_entries(**valid_params.merge(gross_income: 3_000), name: "Acme Corp")
        }.to change(ExternalActivity, :count).by(3)
      end
    end

    describe "duplicate detection for an unnamed submission" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }
      let(:valid_params) { base_params.merge(hours: 300) }

      before { described_class.create_entries(**valid_params) }

      it "creates no entries" do
        expect { described_class.create_entries(**valid_params) }
          .not_to change(ExternalActivity, :count)
      end

      it "treats a blank name as no name" do
        expect { described_class.create_entries(**valid_params, name: "  ") }
          .not_to change(ExternalActivity, :count)
      end
    end

    describe "duplicate detection for a household submission" do
      let(:period_start) { 3.months.ago.beginning_of_month.to_date }
      let(:period_end) { 1.month.ago.end_of_month.to_date }
      let(:household_params) do
        base_params.merge(
          category: ExternalActivity::CATEGORY_HOUSEHOLD,
          gross_income: 300,
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
          .not_to change(ExternalActivity, :count)
      end

      it "accepts the same income from another household member" do
        expect {
          described_class.create_entries(
            **household_params.merge(name: "Richard Doe", identity: [ "000000003", Date.new(1983, 10, 2) ])
          )
        }.to change(ExternalActivity, :count).by(3)
      end

      it "tells household members who share a name apart by tax ID and date of birth" do
        expect {
          described_class.create_entries(**household_params.merge(identity: [ "000000003", Date.new(1983, 10, 2) ]))
        }.to change(ExternalActivity, :count).by(3)
      end

      it "accepts a different income from the same household member" do
        expect { described_class.create_entries(**household_params.merge(gross_income: 450)) }
          .to change(ExternalActivity, :count).by(3)
      end
    end
  end

  # Exactly one determination per save: hours first, falling through to income only when hours
  # fall short. The aggregates run for real; only the threshold checks are stubbed, since the
  # read paths still fetch from the superseded tables until the cutover.
  describe "compliance recalculation" do
    let(:certification) { create(:certification) }
    let(:period_start) { certification.certification_requirements.continuous_lookback_period.start.to_date }
    let(:period_end) { period_start.end_of_month }
    let(:params) do
      {
        member_id: certification.member_id,
        category: "employment",
        period_start:,
        period_end:,
        source_type: ExternalActivity::SOURCE_TYPES[:api]
      }
    end

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    def stub_thresholds(hours_ok:, income_ok:)
      allow(HoursComplianceDeterminationService).to receive(:compliant_for_monthly_hours?).and_return(hours_ok)
      allow(IncomeComplianceDeterminationService).to receive(:compliant_for_monthly_income?).and_return(income_ok)
    end

    def determinations
      Determination.unscope(:order).where(subject_id: certification.id)
    end

    def calculation_type
      latest_determination_for(certification.id).determination_data["calculation_type"]
    end

    context "when the member has an open certification case" do
      let!(:kase) { create(:certification_case, certification: certification) }

      it "records an hours determination for an hours-only row" do
        stub_thresholds(hours_ok: true, income_ok: false)

        expect { described_class.create_entry(**params, hours: 100) }
          .to change(determinations, :count).by(1)

        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
        expect(latest_determination_for(certification.id).outcome).to eq("compliant")
        expect(kase.reload).to be_closed
      end

      it "records a not-compliant hours determination when hours fall short" do
        stub_thresholds(hours_ok: false, income_ok: false)

        described_class.create_entry(**params, hours: 100)

        expect(determinations.count).to eq(1)
        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
        expect(latest_determination_for(certification.id).outcome).to eq("not_compliant")
      end

      it "records an income determination for an income-only row" do
        stub_thresholds(hours_ok: false, income_ok: true)

        described_class.create_entry(**params, gross_income: 600)

        expect(determinations.count).to eq(1)
        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_INCOME_BASED)
        expect(latest_determination_for(certification.id).outcome).to eq("compliant")
      end

      # Hours take precedence, so income is not consulted at all.
      it "records only the hours determination for a combined row whose hours qualify" do
        stub_thresholds(hours_ok: true, income_ok: true)

        described_class.create_entry(**params, hours: 100, gross_income: 600)

        expect(determinations.count).to eq(1)
        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
      end

      it "falls through to income for a combined row whose hours fall short" do
        stub_thresholds(hours_ok: false, income_ok: true)

        described_class.create_entry(**params, hours: 100, gross_income: 600)

        expect(determinations.count).to eq(1)
        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_INCOME_BASED)
        expect(latest_determination_for(certification.id).outcome).to eq("compliant")
      end

      it "records a not-compliant income determination when neither track qualifies" do
        stub_thresholds(hours_ok: false, income_ok: false)

        described_class.create_entry(**params, hours: 100, gross_income: 600)

        expect(determinations.count).to eq(1)
        expect(calculation_type).to eq(Determination::CALCULATION_TYPE_INCOME_BASED)
        expect(latest_determination_for(certification.id).outcome).to eq("not_compliant")
      end

      it "skips recalculation when recalculate_compliance is false" do
        stub_thresholds(hours_ok: true, income_ok: true)

        expect { described_class.create_entry(**params, hours: 100, recalculate_compliance: false) }
          .not_to change(determinations, :count)
      end

      it "recalculates once for the whole submission, not once per entry" do
        stub_thresholds(hours_ok: false, income_ok: false)
        multi_month = params.merge(period_start: period_start, period_end: (period_start + 2.months).end_of_month)

        expect { described_class.create_entries(**multi_month, hours: 300) }
          .to change(determinations, :count).by(1)
      end

      it "recalculates only for a submission that created entries" do
        stub_thresholds(hours_ok: false, income_ok: false)
        described_class.create_entries(**params, hours: 100, name: "Acme Corp")

        expect { described_class.create_entries(**params, hours: 100, name: "Acme Corp") }
          .not_to change(determinations, :count)
      end
    end

    context "when the member has no open certification case" do
      it "creates the row without recording a determination" do
        stub_thresholds(hours_ok: true, income_ok: true)

        expect { described_class.create_entry(**params, hours: 100) }
          .not_to change(Determination, :count)
      end
    end

    context "when the case cannot be resolved" do
      before { create(:certification_case, certification: certification) }

      it "logs a warning rather than failing the save" do
        stub_thresholds(hours_ok: true, income_ok: true)
        allow(Certification).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
        allow(Rails.logger).to receive(:warn)

        expect { described_class.create_entry(**params, hours: 100) }
          .to change(ExternalActivity, :count).by(1)
        expect(Rails.logger).to have_received(:warn).with(/skipped compliance recalculation/)
      end
    end
  end

  describe ".duplicate_entry?" do
    let(:existing_entry) { create(:external_activity, :with_hours, :employment, origin_hash: "abc123") }

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

    it "returns false for a blank origin hash, so unfingerprinted entries never match" do
      create(:external_activity, :with_hours, :employment, origin_hash: nil)

      expect(described_class.duplicate_entry?(nil)).to be false
    end
  end
end
