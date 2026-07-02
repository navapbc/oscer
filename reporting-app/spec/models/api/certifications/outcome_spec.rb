# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::Certifications::Outcome, type: :model do
  describe ".from_certification" do
    let(:certification) { create(:certification) }

    # Stub the business process so creating a certification does not auto-record a determination.
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    it "returns nil when there is no determination" do
      expect(described_class.from_certification(certification)).to be_nil
    end

    context "when the automated exclusion determination excluded the member" do
      before do
        create(:determination,
               subject: certification,
               outcome: "excluded",
               decision_method: "automated",
               reasons: [ "age_under_19_excluded" ])
      end

      it "returns status 'excluded' sourced from the API" do
        outcome = described_class.from_certification(certification)

        expect(outcome.status).to eq("excluded")
        expect(outcome.reason).to eq("age_under_19_excluded")
        expect(outcome.source).to eq("api")
      end
    end

    context "when a staff reviewer approved a manual exemption" do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "manual",
               reasons: [ "exemption_request_compliant" ])
      end

      it "keeps the 'exempt' status distinct from an automated exclusion" do
        outcome = described_class.from_certification(certification)

        expect(outcome.status).to eq("exempt")
        expect(outcome.source).to eq("member")
      end
    end
  end
end
