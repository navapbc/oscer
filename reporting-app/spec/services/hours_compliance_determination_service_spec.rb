# frozen_string_literal: true

require "rails_helper"

RSpec.describe HoursComplianceDeterminationService do
  # Helper to create external_hourly_activity with periods matching the certification's lookback
  def create_external_hourly_activity_for(certification, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = attrs[:period_start] || lookback.start.to_date
    period_end = attrs[:period_end] || lookback.start.to_date.end_of_month

    create(:external_hourly_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, **attrs)
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

    context "when total hours are below target" do
      before do
        create_external_hourly_activity_for(certification, hours: 40)
      end

      it "creates a not_compliant determination" do
        described_class.calculate(certification.id)
        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end

      it "does not close the case" do
        described_class.calculate(certification.id)
        kase = CertificationCase.find_by!(certification_id: certification.id)

        expect(kase).to be_open
      end
    end

    # Every month short of the target even though the months together clear it.
    context "when monthly hours are below target" do
      before do
        certification.certification_requirements.months_that_can_be_certified.each do |month|
          create_external_hourly_activity_for(certification, hours: 40, period_start: month.beginning_of_month,
                                              period_end: month.end_of_month)
        end
      end

      it "creates a not_compliant determination" do
        described_class.calculate(certification.id)
        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end

      it "records the best month, which explains the outcome" do
        described_class.calculate(certification.id)

        data = Determination.where(subject_id: certification.id).last.determination_data
        expect(data["maximum_monthly_hours"]).to eq(40.0)
      end
    end

    context "when hours are below target with NO external hours" do
      # No external hourly activities created - member needs to report from scratch

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
        described_class.calculate(certification_case.certification_id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["total_hours"]).to eq(85.0)
      end

      it "groups hours by category" do
        described_class.calculate(certification_case.certification_id)

        determination = Determination.where(subject_id: certification.id).last
        by_category = determination.determination_data["hours_by_category"]

        expect(by_category["employment"]).to eq(40.0)
        expect(by_category["community_service"]).to eq(30.0)
        expect(by_category["education"]).to eq(15.0)
      end

      it "tracks hours by source" do
        described_class.calculate(certification_case.certification_id)

        determination = Determination.where(subject_id: certification.id).last
        by_source = determination.determination_data["hours_by_source"]

        expect(by_source["external"]).to eq(85.0)
        expect(by_source["activity"]).to eq(0.0)
      end

      it "includes entry IDs in determination_data" do
        described_class.calculate(certification_case.certification_id)

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
        described_class.calculate(certification_case.certification_id)

        determination = Determination.where(subject_id: certification.id).last
        # Should only count 50 hours (within period), not 150 (50 + 100)
        # 50 hours < 80 target = not compliant
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.determination_data["total_hours"]).to eq(50.0)
      end
    end
  end

  describe ".compliant_for_monthly_hours?" do
    let(:target_hours) { 50 }

    before do
      stub_const("HoursComplianceDeterminationService::TARGET_HOURS", target_hours)
    end

    context "when monthly is greater than or equal to target" do
      it { expect(described_class).to be_compliant_for_monthly_hours({ month: target_hours + 10 }) }
      it { expect(described_class).to be_compliant_for_monthly_hours({ month: target_hours }) }
    end

    context "when one of the months is greater than or equal to target" do
      it { expect(described_class).to be_compliant_for_monthly_hours({ month_1: target_hours + 10, month_2: target_hours - 10 }) }
      it { expect(described_class).to be_compliant_for_monthly_hours({ month_1: target_hours, month_2: target_hours - 10 }) }
    end

    context "when monthly is less than target" do
      it { expect(described_class).not_to be_compliant_for_monthly_hours({ month: target_hours - 10 }) }
      it { expect(described_class).not_to be_compliant_for_monthly_hours({ month_1: target_hours - 10, month_2: target_hours - 10 }) }
    end
  end

  describe ".education_enrollment_compliant?" do
    subject(:compliant) { described_class.education_enrollment_compliant?(certification) }

    let(:certification_requirements) { build(:certification_certification_requirements) }
    let(:lookback) { certification_requirements.continuous_lookback_period }
    let(:certification) do
      build(:certification,
        certification_requirements: certification_requirements,
        member_data: build(:certification_member_data, activities: [ activity ]))
    end
    let(:enrollment_status) { "full_time" }
    let(:verification_status) { "verified" }
    let(:period_start) { lookback.start.to_date }
    let(:period_end) { lookback.start.to_date.end_of_month }

    # Symbol keys, but the values stay strings: matched against string constants on Activity, and
    # supplied as strings by the API.
    let(:activity) do
      {
        type: "hourly",
        category: "education",
        enrollment_status: enrollment_status,
        period_start: period_start,
        period_end: period_end,
        verification_status: verification_status
      }
    end

    %w[full_time half_time].each do |status|
      context "when a verified education activity reports #{status} enrollment" do
        let(:enrollment_status) { status }

        it { is_expected.to be(true) }
      end
    end

    context "when enrollment is less than half time" do
      let(:enrollment_status) { "less_than_half_time" }

      it { is_expected.to be(false) }
    end

    context "when no enrollment status is reported" do
      let(:enrollment_status) { nil }

      it { is_expected.to be(false) }
    end

    context "when the enrolled activity is not 'verified'" do
      let(:verification_status) { "self_attested" }

      it { is_expected.to be(false) }
    end

    context "when the enrolled activity ends before the lookback period" do
      let(:period_start) { lookback.start.to_date - 1.month }
      let(:period_end) { lookback.start.to_date - 1.day }

      it { is_expected.to be(false) }
    end

    context "when the enrolled activity starts after the lookback period" do
      let(:period_start) { lookback.end.to_date.end_of_month + 1.day }
      let(:period_end) { period_start.end_of_month }

      it { is_expected.to be(false) }
    end

    context "when the enrolled activity straddles the start of the lookback period" do
      let(:period_start) { lookback.start.to_date - 1.month }
      let(:period_end) { lookback.start.to_date.end_of_month }

      it { is_expected.to be(true) }
    end

    context "when the enrolled activity straddles the end of the lookback period" do
      let(:period_start) { lookback.end.to_date }
      let(:period_end) { lookback.end.to_date.end_of_month + 2.months }

      it { is_expected.to be(true) }
    end

    context "when the member reported no activities" do
      let(:certification) do
        build(:certification,
          certification_requirements: certification_requirements,
          member_data: build(:certification_member_data))
      end

      it { is_expected.to be(false) }
    end
  end

  describe ".summarize_hours" do
    context "when activities are blank" do
      it "returns a summary with zeroed values" do
        summary = described_class.summarize_hours(ExternalHourlyActivity.none)

        expect(summary).to eq({
          total: 0.0,
          by_category: {},
          by_month: {},
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

    it "returns no rows when no application_form is given" do
      rel = described_class.member_hour_activities_for_certification(
        certification,
        application_form: nil
      )

      expect(rel).to be_none
    end

    it "returns only activities with non-nil hours (matching aggregate_hours_for_certification)" do
      create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 12)
      create(:income_activity, activity_report_application_form_id: form.id, month: month_a)

      rel = described_class.member_hour_activities_for_certification(
        certification,
        application_form: form
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
        application_form: form
      )

      expect(rel.to_a).to eq([ second, first ])
    end

    it "scopes rows to the given application_form, not other forms in the certification" do
      other_case = create(:certification_case, certification_id: certification.id)
      other_form = create(:activity_report_application_form, certification_case_id: other_case.id)
      create(:work_activity, activity_report_application_form_id: form.id, month: month_a, hours: 5)
      create(:work_activity, activity_report_application_form_id: other_form.id, month: month_a, hours: 99)

      rel = described_class.member_hour_activities_for_certification(certification, application_form: form)

      expect(rel.count).to eq(1)
      expect(rel.first.hours).to eq(5)
    end
  end

  describe ".aggregate_hours_for_certification" do
    before { allow(Strata::EventManager).to receive(:publish) }

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }
    let(:form) { create(:activity_report_application_form, certification_case_id: certification_case.id) }
    let(:reportable_month) { certification.certification_requirements.continuous_lookback_period.start.to_date }

    it "splits hours by month" do
      certification.certification_requirements.months_that_can_be_certified.each do |month|
        create_external_hourly_activity_for(certification, hours: 40, period_start: month.beginning_of_month,
                                            period_end: month.end_of_month)
      end

      summary = described_class.aggregate_hours_for_certification(certification)
      expect(summary[:hours_by_month].size).to eq certification.certification_requirements.months_that_can_be_certified.size
    end

    it "includes member WorkActivity hours in totals alongside external hours" do
      create_external_hourly_activity_for(certification, category: "employment", hours: 40)
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, category: "education", hours: 12)

      summary = described_class.aggregate_hours_for_certification(certification, application_form: form)

      expect(summary[:hours_by_source][:external]).to eq(40.0)
      expect(summary[:hours_by_source][:activity]).to eq(12.0)
      expect(summary[:total_hours]).to eq(52.0)
      expect(summary[:hours_by_category]["employment"]).to eq(40.0)
      expect(summary[:hours_by_category]["education"]).to eq(12.0)
      expect(summary[:activity_ids].length).to eq(1)
    end

    it "yields zero member hours when no application_form is given" do
      create_external_hourly_activity_for(certification, hours: 40)
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 12)

      summary = described_class.aggregate_hours_for_certification(certification, application_form: nil)

      expect(summary[:hours_by_source][:activity]).to eq(0.0)
      expect(summary[:hours_by_source][:external]).to eq(40.0)
      expect(summary[:total_hours]).to eq(40.0)
      expect(summary[:activity_ids]).to be_empty
    end

    it "uses preloaded member_hour_activity_rows without re-querying member_hour_activities_for_certification" do
      create_external_hourly_activity_for(certification, hours: 40)
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 7)
      create(:work_activity, activity_report_application_form_id: form.id, month: reportable_month, hours: 5)
      rows = described_class.member_hour_activities_for_certification(certification, application_form: form).to_a
      allow(described_class).to receive(:member_hour_activities_for_certification)

      summary = described_class.aggregate_hours_for_certification(
        certification,
        application_form: form,
        member_hour_activity_rows: rows
      )

      expect(described_class).not_to have_received(:member_hour_activities_for_certification)
      expect(summary[:hours_by_source][:activity]).to eq(rows.sum { |r| r.hours.to_f })
      expect(summary[:activity_ids]).to match_array(rows.map(&:id))
    end

    describe "[:enrollment_status]" do
      subject(:enrollment_status) do
        described_class.aggregate_hours_for_certification(enrolled_certification)[:enrollment_status]
      end

      let(:certification_requirements) { build(:certification_certification_requirements) }
      let(:lookback) { certification_requirements.continuous_lookback_period }
      let(:enrolled_certification) do
        build(:certification,
          certification_requirements: certification_requirements,
          member_data: build(:certification_member_data, activities: activities))
      end

      def enrollment(status, verification_status: "verified", period_start: nil, period_end: nil)
        {
          type: "hourly",
          category: "education",
          enrollment_status: status,
          period_start: period_start || lookback.start.to_date,
          period_end: period_end || lookback.start.to_date.end_of_month,
          verification_status: verification_status
        }
      end

      context "when several enrollments were reported" do
        let(:activities) do
          [ enrollment("less_than_half_time"), enrollment("full_time"), enrollment("half_time") ]
        end

        it { is_expected.to eq("full_time") }
      end

      context "when the best reported enrollment is half time" do
        let(:activities) { [ enrollment("less_than_half_time"), enrollment("half_time") ] }

        it { is_expected.to eq("half_time") }
      end

      context "when the only enrollment is less than half time" do
        let(:activities) { [ enrollment("less_than_half_time") ] }

        it { is_expected.to eq("less_than_half_time") }
      end

      context "when a better enrollment is not verified" do
        let(:activities) do
          [ enrollment("full_time", verification_status: "self_attested"), enrollment("half_time") ]
        end

        it { is_expected.to eq("half_time") }
      end

      context "when the only enrollment is not verified" do
        let(:activities) { [ enrollment("full_time", verification_status: "self_attested") ] }

        it { is_expected.to be_nil }
      end

      context "when a better enrollment falls outside the lookback period" do
        let(:activities) do
          [
            enrollment("full_time",
              period_start: lookback.start.to_date - 1.month,
              period_end: lookback.start.to_date - 1.day),
            enrollment("half_time")
          ]
        end

        it { is_expected.to eq("half_time") }
      end

      context "when the member reported hours but no enrollment" do
        let(:activities) do
          [ { type: "hourly", category: "education", hours: 40,
              period_start: lookback.start.to_date, period_end: lookback.start.to_date.end_of_month,
              verification_status: "verified" } ]
        end

        it { is_expected.to be_nil }
      end

      context "when the member reported no activities" do
        let(:activities) { [] }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "TARGET_HOURS" do
    it "defaults to 80" do
      expect(described_class::TARGET_HOURS).to eq(80)
    end
  end
end
