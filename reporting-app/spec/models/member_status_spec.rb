# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberStatus do
  describe "#dashboard_report_status" do
    it "maps awaiting_report to in_progress" do
      ms = described_class.new(status: described_class::AWAITING_REPORT)
      expect(ms.dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_IN_PROGRESS)
    end

    it "maps pending_review to under_review" do
      ms = described_class.new(status: described_class::PENDING_REVIEW)
      expect(ms.dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_UNDER_REVIEW)
    end

    it "maps compliant token" do
      ms = described_class.new(status: described_class::COMPLIANT)
      expect(ms.dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_COMPLIANT)
    end

    it "maps not_compliant token" do
      ms = described_class.new(status: described_class::NOT_COMPLIANT)
      expect(ms.dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_NOT_COMPLIANT)
    end

    it "maps exempt token" do
      ms = described_class.new(status: described_class::EXEMPT)
      expect(ms.dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_EXEMPT)
    end

    it "falls back to in_progress for unknown status values (defensive else branch)" do
      expect(described_class.new(status: "garbage").dashboard_report_status).to eq(described_class::DASHBOARD_REPORT_IN_PROGRESS)
    end
  end

  describe "serialization" do
    it "does not embed latest_determination in JSON" do
      det = build_stubbed(:determination)
      ms = described_class.new(
        status: described_class::COMPLIANT,
        determination_method: "automated",
        reason_codes: [ "hours_reported_compliant" ],
        human_readable_reason_codes: [ "Hours reported compliant" ]
      )
      ms.latest_determination = det

      json = ms.to_json
      expect(json).not_to include(det.id)
      expect(json).not_to include(det.subject_id)
    end
  end
end
