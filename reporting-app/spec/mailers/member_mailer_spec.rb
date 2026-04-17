# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberMailer, type: :mailer do
  # Stub business process to prevent auto-triggering when creating certifications
  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(CommunityEngagementDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  let(:certification) do
    create(
      :certification,
      member_data: build(:certification_member_data, :with_account_email, :with_full_name)
    )
  end

  describe "#exempt_email" do
    let(:mail) { described_class.with(certification: certification).exempt_email }

    it "renders the headers" do
      expect(mail.subject).to match(/No action needed/)
      expect(mail.to).to eq([ certification.member_email ])
    end

    it "includes certification date in subject" do
      period = certification.certification_requirements.certification_date.strftime("%B %Y")
      expect(mail.subject).to include(period)
    end

    it "renders the body" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#action_required_email" do
    let(:mail) { described_class.with(certification: certification).action_required_email }

    it "renders the headers" do
      expect(mail.subject).to match(/Action Needed/)
      expect(mail.to).to eq([ certification.member_email ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#compliant_email" do
    let(:mail) { described_class.with(certification: certification).compliant_email }

    it "renders the headers" do
      expect(mail.subject).to match(/No action needed/)
      expect(mail.to).to eq([ certification.member_email ])
    end

    it "includes certification date in subject" do
      period = certification.certification_requirements.certification_date.strftime("%B %Y")
      expect(mail.subject).to include(period)
    end

    it "renders the body" do
      expect(mail.body.encoded).to be_present
    end

    it "includes compliance status text" do
      expect(mail.body.encoded).to include("compliance status")
    end

    it "includes good news message" do
      expect(mail.body.encoded).to include("Good news")
    end

    context "with ce_satisfied_by from ex parte CE" do
      let(:mail) do
        described_class.with(certification: certification, ce_satisfied_by: :hours).compliant_email
      end

      it "includes the hours CE intro line" do
        expect(mail.html_part.body.decoded).to include("community engagement requirement through your reported hours")
      end
    end
  end

  describe "#insufficient_hours_email" do
    let(:hours_data) { { total_hours: 50.0, hours_by_category: { "employment" => 50.0 } } }
    let(:target_hours) { 80 }
    let(:mail) do
      described_class.with(
        certification: certification,
        hours_data: hours_data,
        target_hours: target_hours
      ).insufficient_hours_email
    end

    it "renders the headers" do
      expect(mail.subject).to match(/Action needed/)
      expect(mail.to).to eq([ certification.member_email ])
    end

    it "includes hours needed in subject" do
      expect(mail.subject).to include("30 more hours")
    end

    it "includes deadline in subject" do
      deadline = certification.certification_requirements.due_date.strftime("%B %d, %Y")
      expect(mail.subject).to include(deadline)
    end

    it "renders the body" do
      expect(mail.body.encoded).to be_present
    end

    it "includes progress message" do
      expect(mail.body.encoded).to include("making progress")
    end

    it "includes hours reported" do
      expect(mail.body.encoded).to include("50 hours")
    end

    it "includes hours still needed" do
      expect(mail.body.encoded).to include("30 hours")
    end

    it "includes exemption notice" do
      expect(mail.body.encoded).to include("may be excused")
    end

    it "includes coverage warning" do
      expect(mail.body.encoded).to include("Medicaid coverage may end")
    end
  end

  describe "#community_engagement_insufficient_email" do
    let(:hours_data) { { total_hours: 50.0, hours_by_category: {}, hours_by_source: { ex_parte: 50, activity: 0 } } }
    let(:income_data) do
      {
        total_income: BigDecimal("400"),
        income_by_source: { income: BigDecimal("400"), activity: BigDecimal("0") },
        income_ids: [],
        period_start: Date.current,
        period_end: Date.current
      }
    end

    context "when only the income section applies" do
      let(:mail) do
        described_class.with(
          certification: certification,
          hours_data: hours_data,
          income_data: income_data,
          show_hours: false,
          show_income: true,
          target_hours: 80,
          target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
        ).community_engagement_insufficient_email
      end

      it "includes income shortfall in subject" do
        expect(mail.subject).to include("$180")
      end

      it "includes income reported in body" do
        expect(mail.body.encoded).to include("$400")
      end
    end

    context "when both sections apply" do
      let(:mail) do
        described_class.with(
          certification: certification,
          hours_data: hours_data,
          income_data: income_data,
          show_hours: true,
          show_income: true,
          target_hours: 80,
          target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
        ).community_engagement_insufficient_email
      end

      it "mentions both hours and income in the subject" do
        expect(mail.subject).to include("more hours")
        expect(mail.subject).to include("more in monthly income")
      end
    end
  end
end
