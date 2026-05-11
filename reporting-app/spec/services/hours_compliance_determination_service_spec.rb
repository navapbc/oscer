# frozen_string_literal: true

require "rails_helper"

RSpec.describe HoursComplianceDeterminationService do
  # Helper to create external_hourly_activity with periods matching the certification's lookback
  def create_external_hourly_activity_for(certification, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:external_hourly_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, **attrs)
  end

  describe ".determine" do
    # Stub EventManager BEFORE creating certification to prevent auto-triggering business process
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }

    context "when hours meet target" do
      before do
        create_external_hourly_activity_for(certification, hours: 85)
      end

      it "publishes DeterminedHoursMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedHoursMet",
          hash_including(case_id: certification_case.id)
        )
      end

      it "creates a compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("hours_reported_compliant")
      end

      it "closes the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_closed
      end

      it "includes determination_data with calculation details" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        data = determination.determination_data

        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
        expect(data["total_hours"]).to eq(85.0)
        expect(data["target_hours"]).to eq(80)
      end
    end

    context "when hours are below target with external hours" do
      before do
        create_external_hourly_activity_for(certification, hours: 50)
      end

      it "publishes DeterminedHoursInsufficient event (has some hours but needs more)" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedHoursInsufficient",
          hash_including(case_id: certification_case.id)
        )
      end

      it "creates a not_compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end

      it "does not close the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).not_to be_closed
      end
    end

    context "when hours are below target with NO external hours" do
      # No external hourly activities created - member needs to report from scratch

      it "publishes DeterminedActionRequired event (no hours found)" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end

      it "creates a not_compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end
    end

    context "when hours exactly meet target" do
      before do
        create_external_hourly_activity_for(certification, hours: 80)
      end

      it "publishes DeterminedHoursMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedHoursMet",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "with no hours data" do
      it "publishes DeterminedActionRequired event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end
    end
  end

  describe ".calculate" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
      # CertificationCase must exist for calculate to work (mirrors production behavior)
      create(:certification_case, certification_id: certification.id)
    end

    let(:certification) { create(:certification) }

    context "when hours meet target" do
      before do
        create_external_hourly_activity_for(certification, hours: 90)
      end

      it "creates a compliant determination" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("hours_reported_compliant")
        expect(determination.decision_method).to eq("automated")
      end

      it "closes the certification case when compliant (parity with income calculate)" do
        kase = CertificationCase.find_by!(certification_id: certification.id)
        expect(kase).to be_open

        described_class.calculate(certification.id)

        expect(kase.reload).to be_closed
      end

      it "includes determination_data with calculation details" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        data = determination.determination_data

        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
        expect(data["total_hours"]).to eq(90.0)
        expect(data["target_hours"]).to eq(80)
      end
    end

    context "when hours are below target" do
      before do
        create_external_hourly_activity_for(certification, hours: 40)
      end

      it "creates a not_compliant determination" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end
    end
  end

  describe "hours aggregation" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }

    context "with multiple external hourly activities" do
      before do
        create_external_hourly_activity_for(certification, category: "employment", hours: 40)
        create_external_hourly_activity_for(certification, category: "community_service", hours: 30)
        create_external_hourly_activity_for(certification, category: "education", hours: 15)
      end

      it "sums hours across all entries" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["total_hours"]).to eq(85.0)
      end

      it "groups hours by category" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        by_category = determination.determination_data["hours_by_category"]

        expect(by_category["employment"]).to eq(40.0)
        expect(by_category["community_service"]).to eq(30.0)
        expect(by_category["education"]).to eq(15.0)
      end

      it "tracks hours by source" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        by_source = determination.determination_data["hours_by_source"]

        expect(by_source["external"]).to eq(85.0)
        expect(by_source["activity"]).to eq(0.0)
      end

      it "includes entry IDs in determination_data" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["external_hourly_activity_ids"].length).to eq(3)
      end
    end

    context "with activities outside lookback period" do
      before do
        # Create activity within lookback period
        create_external_hourly_activity_for(certification, hours: 50)

        # Create activity outside lookback period (far in the past)
        create(:external_hourly_activity,
               member_id: certification.member_id,
               hours: 100,
               period_start: 2.years.ago.to_date,
               period_end: 2.years.ago.to_date.end_of_month)
      end

      it "only counts hours within the lookback period" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        # Should only count 50 hours (within period), not 150 (50 + 100)
        # 50 hours < 80 target = not compliant
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.determination_data["total_hours"]).to eq(50.0)
      end
    end
  end

  describe ".compliant_for_total_hours?" do
    let(:target_hours) { 50 }

    before do
      stub_const("HoursComplianceDeterminationService::TARGET_HOURS", target_hours)
    end

    context "when total is greater than or equal to target" do
      it { expect(described_class).to be_compliant_for_total_hours(target_hours + 10) }
      it { expect(described_class).to be_compliant_for_total_hours(target_hours) }
    end

    context "when total is less than target" do
      it { expect(described_class).not_to be_compliant_for_total_hours(target_hours - 10) }
    end
  end

  describe ".summarize_hours" do
    context "when activities are blank" do
      it "returns a summary with zeroed values" do
        summary = described_class.summarize_hours(ExternalHourlyActivity.none)

        expect(summary).to eq({
          total: 0.0,
          by_category: {},
          ids: []
        })
      end
    end
  end

  describe ".member_hour_activities_for_certification" do
    before { allow(Strata::EventManager).to receive(:publish) }

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }
    let(:form) { create(:activity_report_application_form, certification_case_id: certification_case.id) }
    let(:month_a) { Date.new(2024, 1, 1) }
    let(:month_b) { Date.new(2024, 2, 1) }

    it "returns no rows when the case has no activity report" do
      other_case = create(:certification_case, certification_id: certification.id)

      rel = described_class.member_hour_activities_for_certification(
        certification,
        certification_case: other_case
      )

      expect(rel).to be_none
    end

    it "returns only activities with non-nil hours (matching aggregate_hours_for_certification)" do
      create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 12)
      create(:income_activity, activity_report_application_form_id: form.id, month: month_a)

      rel = described_class.member_hour_activities_for_certification(
        certification,
        certification_case: certification_case
      )

      expect(rel.count).to eq(1)
      expect(rel.first).to be_a(WorkActivity)
      expect(rel.first.hours).to eq(12)
    end

    it "orders by month then created_at" do
      first = create(:work_activity, activity_report_application_form_id: form.id, month: month_b, hours: 1)
      second = create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 2)

      rel = described_class.member_hour_activities_for_certification(
        certification,
        certification_case: certification_case
      )

      expect(rel.to_a).to eq([ second, first ])
    end

    it "scopes to the given certification case when multiple cases share a certification" do
      other_case = create(:certification_case, certification_id: certification.id)
      create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 5)

      empty = described_class.member_hour_activities_for_certification(
        certification,
        certification_case: other_case
      )
      from_form_case = described_class.member_hour_activities_for_certification(
        certification,
        certification_case: certification_case
      )

      expect(empty).to be_none
      expect(from_form_case.count).to eq(1)
    end

    context "when certification_case is omitted" do
      it "resolves the case via the shared deterministic helper" do
        create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 7)

        rel = described_class.member_hour_activities_for_certification(certification)

        expect(rel.count).to eq(1)
        expect(rel.first.hours).to eq(7)
      end
    end
  end

  describe ".aggregate_hours_for_certification (multi-case parity)" do
    before { allow(Strata::EventManager).to receive(:publish) }

    let(:certification) { create(:certification) }
    let!(:case_with_form) { create(:certification_case, certification_id: certification.id) }
    let!(:other_case) { create(:certification_case, certification_id: certification.id) }
    let!(:form) { create(:activity_report_application_form, certification_case_id: case_with_form.id) }
    let(:lookback) { certification.certification_requirements.continuous_lookback_period }
    let(:reportable_month) { lookback.start.to_date }

    it "uses the case whose form holds the rows when multiple cases share a certification" do
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 12)

      summary = described_class.aggregate_hours_for_certification(certification, certification_case: case_with_form)

      expect(summary[:hours_by_source][:activity]).to eq(12.0)
      expect(summary[:total_hours]).to eq(12.0)
    end

    it "yields zero member hours when passed a case without a form (other case in the certification)" do
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 12)

      summary = described_class.aggregate_hours_for_certification(certification, certification_case: other_case)

      expect(summary[:hours_by_source][:activity]).to eq(0.0)
      expect(summary[:total_hours]).to eq(0.0)
    end

    it "matches the displayed rows when member_hour_activity_rows are passed in" do
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 12)
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 8)

      rows = described_class.member_hour_activities_for_certification(certification, certification_case: case_with_form).to_a
      summary = described_class.aggregate_hours_for_certification(
        certification,
        certification_case: case_with_form,
        member_hour_activity_rows: rows
      )

      expect(summary[:hours_by_source][:activity]).to eq(rows.sum { |r| r.hours.to_f })
      expect(summary[:activity_ids]).to match_array(rows.map(&:id))
    end
  end

  describe "TARGET_HOURS" do
    it "defaults to 80" do
      expect(described_class::TARGET_HOURS).to eq(80)
    end
  end
end
