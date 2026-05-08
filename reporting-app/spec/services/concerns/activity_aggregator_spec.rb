# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityAggregator, type: :concern do
  class TestDeterminationService
    include ActivityAggregator
  end

  let(:service) { TestDeterminationService.new }

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
