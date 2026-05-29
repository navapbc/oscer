# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomeComplianceDeterminationService do
  def expect_no_ce_workflow_events_published
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedHoursMet", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedHoursInsufficient", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedCommunityEngagementMet", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedCommunityEngagementInsufficient", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedCommunityEngagementActionRequired", anything)
  end

  # ExternalIncomeActivity rows aligned with the certification's continuous
  # lookback (parity with external hours helper).
  def create_income_for(certification, gross_income:, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:external_income_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, gross_income: gross_income, **attrs)
  end

  describe "TARGET_INCOME_MONTHLY" do
    it "defaults to 580" do
      expect(described_class::TARGET_INCOME_MONTHLY).to eq(BigDecimal("580"))
    end
  end

  describe ".compliant_for_total_income?" do
    it "is true at or above the monthly threshold" do
      expect(described_class.compliant_for_total_income?(described_class::TARGET_INCOME_MONTHLY)).to be true
      expect(described_class.compliant_for_total_income?(described_class::TARGET_INCOME_MONTHLY + 1)).to be true
    end

    it "is false below the monthly threshold" do
      expect(described_class.compliant_for_total_income?(described_class::TARGET_INCOME_MONTHLY - 1)).to be false
    end
  end

  describe ".calculate" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
      create(:certification_case, certification: certification)
    end

    let(:certification) { create(:certification) }

    context "when income meets target" do
      before do
        create_income_for(certification, gross_income: 600)
      end

      it "creates a compliant automated determination (no workflow events from this method)" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("income_reported_compliant")
        expect(determination.decision_method).to eq("automated")
        expect_no_ce_workflow_events_published
      end

      it "closes the certification case when compliant (parity with hours calculate)" do
        kase = CertificationCase.find_by!(certification_id: certification.id)
        expect(kase).to be_open

        described_class.calculate(certification.id)

        expect(kase.reload).to be_closed
      end
    end

    context "when income is below target" do
      before do
        create_income_for(certification, gross_income: 100)
      end

      it "creates a not_compliant determination" do
        kase = CertificationCase.find_by!(certification_id: certification.id)
        expect(kase).to be_open

        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("income_reported_insufficient")
        expect_no_ce_workflow_events_published
        expect(kase.reload).to be_open
      end
    end
  end

  describe "income aggregation" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
      create(:certification_case, certification: certification)
    end

    let(:certification) { create(:certification) }

    context "with multiple ExternalIncomeActivity rows in lookback" do
      before do
        create_income_for(certification, gross_income: 300.0, category: "employment")
        create_income_for(certification, gross_income: 280.25, category: "education")
      end

      it "sums gross_income across rows when persisting via calculate" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["total_income"]).to eq(580.25)
      end

      it "includes external_income_activity_ids" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["external_income_activity_ids"].length).to eq(2)
      end

      it "includes empty activity_ids when the case has no member IncomeActivity rows in the lookback" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["activity_ids"]).to eq([])
      end
    end

    context "with member IncomeActivity rows in the lookback" do
      before do
        allow(Strata::EventManager).to receive(:publish)
        allow(NotificationService).to receive(:send_email_notification)
        kase = create(:certification_case, certification: certification)
        form = create(:activity_report_application_form, certification_case_id: kase.id)
        lookback = certification.certification_requirements.continuous_lookback_period
        month = lookback.start.to_date
        form.activities.create!(
          type: "IncomeActivity",
          name: "Side gig",
          category: "employment",
          month: month,
          income: 10_000
        )
        create_income_for(certification, gross_income: 300)
      end

      it "persists activity_ids for member IncomeActivity rows when calculating" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["activity_ids"].length).to eq(1)
      end
    end

    context "with income outside lookback period" do
      before do
        create_income_for(certification, gross_income: 300)

        create(:external_income_activity,
               member_id: certification.member_id,
               gross_income: 10_000,
               period_start: 2.years.ago.to_date,
               period_end: 2.years.ago.to_date.end_of_month)
      end

      it "only counts income within the lookback period" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.determination_data["total_income"]).to eq(300.0)
      end
    end
  end

  describe ".member_income_activities_for_certification" do
    it "does not use an ActiveRecord :income association (Strata money on IncomeActivity)" do
      expect(IncomeActivity.reflect_on_association(:income)).to be_nil
    end
  end

  describe ".aggregate_income_for_certification" do
    before do
      allow(Strata::EventManager).to receive(:publish)
    end

    let(:certification) { create(:certification) }

    it "includes member IncomeActivity amounts in totals with external income rows" do
      kase = create(:certification_case, certification: certification)
      form = create(:activity_report_application_form, certification_case_id: kase.id)
      lookback = certification.certification_requirements.continuous_lookback_period
      month = lookback.start.to_date

      income_activity = form.activities.create!(
        type: "IncomeActivity",
        name: "Food Bank",
        category: "community_service",
        month: month,
        income: 5_000
      )
      create_income_for(certification, gross_income: 100)

      agg = described_class.aggregate_income_for_certification(certification, certification_case: kase)

      # Strata :money on IncomeActivity — assert against the persisted record, not a magic dollar amount.
      expected_member_total = BigDecimal((income_activity.reload.income&.dollar_amount || 0).to_s)
      expect(agg[:income_by_source][:activity]).to eq(expected_member_total)
      expect(agg[:income_by_source][:external]).to eq(BigDecimal("100"))
      expect(agg[:total_income]).to eq(expected_member_total + BigDecimal("100"))
      expect(agg[:activity_ids].length).to eq(1)
      expect(agg[:external_income_activity_ids].length).to eq(1)
    end

    it "uses preloaded member income rows without calling member_income_activities_for_certification again" do
      kase = create(:certification_case, certification: certification)
      form = create(:activity_report_application_form, certification_case_id: kase.id)
      lookback = certification.certification_requirements.continuous_lookback_period
      month = lookback.start.to_date
      form.activities.create!(
        type: "IncomeActivity",
        name: "Pantry",
        category: "community_service",
        month: month,
        income: 2_000
      )
      ext_row = create_income_for(certification, gross_income: 50)
      ext_scope = ExternalIncomeActivity.where(id: ext_row.id)
      rows = described_class.member_income_activities_for_certification(
        certification,
        certification_case: kase
      ).to_a

      call_count = 0
      original = described_class.method(:member_income_activities_for_certification)
      allow(described_class).to receive(:member_income_activities_for_certification) do |*args, **kwargs|
        call_count += 1
        original.call(*args, **kwargs)
      end

      agg = described_class.aggregate_income_for_certification(
        certification,
        certification_case: kase,
        external_income_activities: ext_scope,
        member_income_activity_rows: rows
      )

      expect(call_count).to eq(0)
      expect(agg[:activity_ids]).to eq(rows.map(&:id))
      expect(agg[:external_income_activity_ids]).to eq([ ext_row.id ])
    end

    it "returns expected aggregate structure" do
      create_income_for(certification, gross_income: 100)
      agg = described_class.aggregate_income_for_certification(certification)

      expect(agg).to have_key(:total_income)
      expect(agg).to have_key(:income_by_source)
      expect(agg).to have_key(:external_income_activity_ids)
      expect(agg).to have_key(:activity_ids)
      expect(agg).to have_key(:period_start)
      expect(agg).to have_key(:period_end)

      expect(agg[:income_by_source]).to have_key(:external)
      expect(agg[:income_by_source]).to have_key(:activity)

      expect(agg[:external_income_activity_ids].length).to eq(1)
      expect(agg[:activity_ids].length).to eq(0)
    end

    context "when resolving certification case without explicit certification_case (tie-break)" do
      let(:certification) { create(:certification) }

      it "prefers the case with an activity report form over a newer case without a form" do
        older_case = CertificationCase.create!(
          certification_id: certification.id,
          business_process_current_step: "report_activities",
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )
        CertificationCase.create!(
          certification_id: certification.id,
          business_process_current_step: "report_activities",
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )
        form = create(:activity_report_application_form, certification_case_id: older_case.id)
        lookback = certification.certification_requirements.continuous_lookback_period
        month = lookback.start.to_date
        income_activity = form.activities.create!(
          type: "IncomeActivity",
          name: "Co-op",
          category: "employment",
          month: month,
          income: 7_000
        )
        create_income_for(certification, gross_income: 40)

        agg = described_class.aggregate_income_for_certification(certification)

        expect(agg[:activity_ids]).to eq([ income_activity.id ])
        expected_member = BigDecimal((income_activity.reload.income&.dollar_amount || 0).to_s)
        expect(agg[:income_by_source][:activity]).to eq(expected_member)
      end
    end

    context "when resolving certification case without explicit certification_case (multi-case logging)" do
      let(:certification) { create(:certification) }

      it "logs at debug when multiple certification cases share certification_id" do
        # :certification_case factory uses find_or_create_by(certification_id:), so two factories
        # would still yield one row; create two real rows to exercise the multi-case branch.
        CertificationCase.create!(
          certification_id: certification.id,
          business_process_current_step: "report_activities",
          created_at: 2.days.ago,
          updated_at: 2.days.ago
        )
        CertificationCase.create!(
          certification_id: certification.id,
          business_process_current_step: "report_activities",
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        received = []
        allow(Rails.logger).to receive(:debug) do |&block|
          received << block.call if block
        end

        described_class.aggregate_income_for_certification(certification)

        expect(received).to include(
          a_string_including("multiple CertificationCases", certification.id)
        )
      end

      it "does not emit multi-case debug when only one certification case exists" do
        create(:certification_case, certification: certification)

        received = []
        allow(Rails.logger).to receive(:debug) do |&block|
          received << block.call if block
        end

        described_class.aggregate_income_for_certification(certification)

        expect(received.none? { |m| m.include?("multiple CertificationCases") }).to be true
      end
    end
  end
end
