# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberMailer, type: :mailer do
  let(:certification) do
    create(
      :certification,
      member_data: build(:certification_member_data, :with_account_email, :with_full_name)
    )
  end

  describe "#exempt_email" do
    let(:mail) { described_class.with(certification: certification).exempt_email }

    it "renders the headers" do
      expect(mail.subject).to match(/No Action Needed/)
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
end
