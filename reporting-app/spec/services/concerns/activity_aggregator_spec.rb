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
        create(:external_activity, :with_income,
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
      let(:activities) { create_list(:external_activity, num_activities, :with_income, gross_income: gross_income) }

      it "returns total and ids" do
        summary = service.summarize_income(ExternalActivity.with_income.where(id: activities.map(&:id)))

        expect(summary[:total]).to eq(BigDecimal(gross_income * num_activities))
        expect(summary[:ids].length).to eq(num_activities)
      end
    end

    context "with no activities" do
      it "returns zeroed values" do
        summary = service.summarize_income(ExternalActivity.none)

        expect(summary[:total]).to eq(BigDecimal(0))
        expect(summary[:ids].length).to eq(0)
      end
    end
  end

  describe ".apportioned_multi_values_map" do
    def shares(period_start, period_end, weight:, **values)
      service.apportioned_multi_values_map(period_start, period_end, weight:, **values)
    end

    context "with :daily weights" do
      # Jan 20-31 is 12 days and Feb 1-10 is 10 days, so a 22-unit total splits 12/10.
      it "apportions each value by the days its month covers" do
        result = shares(Date.new(2026, 1, 20), Date.new(2026, 2, 10), weight: :daily,
                        hours: 22, gross_income: 220)

        expect(result.map { |month_start, _, _| month_start })
          .to eq([ Date.new(2026, 1, 20), Date.new(2026, 2, 1) ])
        expect(result.map { |_, _, values| values[:hours] }).to eq([ 12, 10 ])
        expect(result.map { |_, _, values| values[:gross_income] }).to eq([ 120, 100 ])
      end
    end

    context "with :monthly weights" do
      it "apportions each value evenly across the months" do
        result = shares(Date.new(2026, 1, 1), Date.new(2026, 3, 31), weight: :monthly, gross_income: 300)

        expect(result.map { |_, _, values| values[:gross_income] }).to eq([ 100, 100, 100 ])
      end
    end

    it "sums each value back to its total without rounding drift" do
      result = shares(Date.new(2026, 5, 1), Date.new(2026, 7, 31), weight: :daily,
                      hours: BigDecimal("100"), gross_income: BigDecimal("1000"))

      expect(result.sum { |_, _, values| values[:hours] }).to eq(BigDecimal("100"))
      expect(result.sum { |_, _, values| values[:gross_income] }).to eq(BigDecimal("1000"))
    end

    # Apportioning the values independently and zipping the results would drop a month for one
    # value but not the other, misaligning the two lists.
    it "keeps months aligned when one value's share rounds to zero" do
      result = shares(Date.new(2026, 1, 31), Date.new(2026, 3, 31), weight: :daily,
                      hours: 300, gross_income: BigDecimal("0.02"))

      expect(result.size).to eq(3)
      expect(result.map { |_, _, values| values[:hours] }).to all be > 0
      expect(result.map { |_, _, values| values[:gross_income] }).to include(nil)
      expect(result.sum { |_, _, values| values[:gross_income] || 0 }).to eq(BigDecimal("0.02"))
    end

    it "drops a month only when every value's share rounds to zero" do
      result = shares(Date.new(2026, 1, 31), Date.new(2026, 12, 31), weight: :daily,
                      hours: 1, gross_income: BigDecimal("0.05"))

      expect(result.map { |month_start, _, _| month_start }).not_to include(Date.new(2026, 1, 31))
    end

    it "returns the whole period unsplit when it falls inside one month" do
      result = shares(Date.new(2026, 1, 5), Date.new(2026, 1, 20), weight: :daily, hours: 40)

      expect(result).to eq([ [ Date.new(2026, 1, 5), Date.new(2026, 1, 20), { hours: 40 } ] ])
    end

    # Malformed input goes to the model as-is so it raises RecordInvalid rather than failing here.
    it "returns the whole period when every value is blank" do
      result = shares(Date.new(2026, 1, 1), Date.new(2026, 3, 31), weight: :daily,
                      hours: nil, gross_income: nil)

      expect(result.size).to eq(1)
      expect(result.first.last).to eq({ hours: nil, gross_income: nil })
    end

    it "returns the whole period when the period is reversed" do
      result = shares(Date.new(2026, 3, 31), Date.new(2026, 1, 1), weight: :daily, hours: 40)

      expect(result).to eq([ [ Date.new(2026, 3, 31), Date.new(2026, 1, 1), { hours: 40 } ] ])
    end
  end
end
