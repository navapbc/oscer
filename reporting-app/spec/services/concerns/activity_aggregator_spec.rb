# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityAggregator, type: :concern do
  subject(:service) { TestDeterminationService.new }

  before do
    stub_const(
      "TestDeterminationService",
      Class.new { include ActivityAggregator }
    )
  end


  describe ".fetch_external_income_activities" do
    let(:certification) { create(:certification) }

    context "with member_id" do
      before do
        lookback = certification.certification_requirements.continuous_lookback_period
        create(:external_income_activity,
               member_id: certification.member_id,
               gross_income: 100,
               period_start: lookback.start.to_date,
               period_end: lookback.start.to_date.end_of_month)
      end

      it "returns activities for the member within the lookback period" do
        activities = service.fetch_external_income_activities(
          certification,
          certification.certification_requirements.continuous_lookback_period
        )

        expect(activities.count).to eq(1)
        expect(activities.first.member_id).to eq(certification.member_id)
      end
    end

    context "with nil member_id" do
      let(:certification) { create(:certification, member_id: nil) }

      it "returns empty relation" do
        activities = service.fetch_external_income_activities(
          certification,
          certification.certification_requirements.continuous_lookback_period
        )

        expect(activities).to be_empty
        expect(activities.count).to eq(0)
      end
    end
  end

  describe ".certification_case_for_certification" do
    # Stub Strata events so the :certification factory does not trigger a business process
    # step that auto-creates a CertificationCase (which would skew the multi-case scenarios below).
    before { allow(Strata::EventManager).to receive(:publish) }

    let(:certification) { create(:certification) }

    it "returns the passed-in case unchanged" do
      kase = create(:certification_case, certification_id: certification.id)
      other = create(:certification_case, certification_id: certification.id)

      expect(service.certification_case_for_certification(certification, kase)).to eq(kase)
      expect(service.certification_case_for_certification(certification, other)).to eq(other)
    end

    it "returns the single case when only one exists" do
      kase = create(:certification_case, certification_id: certification.id)

      expect(service.certification_case_for_certification(certification)).to eq(kase)
    end

    it "returns the newest case when multiple exist without an activity report" do
      create(:certification_case, certification_id: certification.id, created_at: 2.days.ago)
      newer = create(:certification_case, certification_id: certification.id, created_at: 1.day.ago)

      expect(service.certification_case_for_certification(certification)).to eq(newer)
    end

    it "prefers a case that owns an ActivityReportApplicationForm over a newer case without one" do
      with_form = create(:certification_case, certification_id: certification.id, created_at: 2.days.ago)
      create(:activity_report_application_form, certification_case_id: with_form.id)
      create(:certification_case, certification_id: certification.id, created_at: 1.day.ago)

      expect(service.certification_case_for_certification(certification)).to eq(with_form)
    end

    it "picks the newest case with a form when multiple cases have forms" do
      older_with_form = create(:certification_case, certification_id: certification.id, created_at: 2.days.ago)
      create(:activity_report_application_form, certification_case_id: older_with_form.id)
      newer_with_form = create(:certification_case, certification_id: certification.id, created_at: 1.day.ago)
      create(:activity_report_application_form, certification_case_id: newer_with_form.id)

      expect(service.certification_case_for_certification(certification)).to eq(newer_with_form)
    end

    it "returns nil when no cases exist for the certification" do
      other_certification = create(:certification)

      expect(service.certification_case_for_certification(other_certification)).to be_nil
    end
  end

  describe ".summarize_income" do
    context "with activities" do
      let(:num_activities) { 2 }
      let(:gross_income) { 100 }
      let(:activities) { create_list(:external_income_activity, num_activities, gross_income: gross_income) }

      it "returns total and ids" do
        summary = service.summarize_income(ExternalIncomeActivity.where(id: activities.map(&:id)))

        expect(summary[:total]).to eq(BigDecimal(gross_income * num_activities))
        expect(summary[:ids].length).to eq(num_activities)
      end
    end

    context "with no activities" do
      it "returns zeroed values" do
        summary = service.summarize_income(ExternalIncomeActivity.none)

        expect(summary[:total]).to eq(BigDecimal(0))
        expect(summary[:ids].length).to eq(0)
      end
    end
  end
end
