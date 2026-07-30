# frozen_string_literal: true

require "rails_helper"

RSpec.describe Verification::Adapters::MockCommunityEngagement do
  subject(:result) { described_class.new.call(certification: certification) }

  let(:certification) do
    build(:certification, member_data: build(:certification_member_data, **member_data_attrs))
  end
  let(:member_data_attrs) { { account_email: account_email } }
  let(:trigger) { described_class::TRIGGER_EMAIL_SUBSTRING }

  describe ".declared_outcomes" do
    let(:account_email) { nil }

    it "declares the hours-met community-engagement outcome key" do
      expect(described_class.declared_outcomes).to contain_exactly(:hours_reported_compliant)
    end

    it "declares only Determination reason-code mapping keys" do
      expect(described_class.declared_outcomes).to all(be_in(Determination::REASON_CODE_MAPPING.keys))
    end

    it "declares only non-exclusion (order-bearing) outcome keys" do
      expect(described_class.declared_outcomes).to all(satisfy { |key| Exclusion.find(key).nil? })
    end
  end

  describe "#call" do
    context "when the member has no email" do
      let(:account_email) { nil }

      it_behaves_like "a skipped verification result"
    end

    context "when the email is a blank string" do
      let(:account_email) { "" }

      it_behaves_like "a skipped verification result"
    end

    context "when the email does not contain the trigger" do
      let(:account_email) { "member@example.com" }

      it_behaves_like "a successful verification result"

      it "returns no result (empty outcomes)" do
        expect(result.outcomes).to eq([])
      end

      it "tags the audit data with the source" do
        expect(result.audit_data[:source]).to eq("mock_community_engagement")
      end
    end

    context "when the email contains the trigger" do
      let(:account_email) { "member+#{described_class::TRIGGER_EMAIL_SUBSTRING}@example.com" }

      it_behaves_like "a successful verification result"

      it "attests the community-engagement requirement is met" do
        expect(result.outcomes).to eq([ :hours_reported_compliant ])
      end

      it "tags the audit data with the source" do
        expect(result.audit_data[:source]).to eq("mock_community_engagement")
      end
    end

    context "when the trigger appears in the local part in mixed case" do
      let(:account_email) { "Member.CE-Met@Example.com" }

      it "matches case-insensitively so a capitalized demo email still fires" do
        expect(result.outcomes).to eq([ :hours_reported_compliant ])
      end
    end

    context "when the trigger is present only on the contact email" do
      let(:member_data_attrs) { { contact: { email: "contact+#{described_class::TRIGGER_EMAIL_SUBSTRING}@example.com" } } }

      it "reads through Certification#member_email so either email field works" do
        expect(result.outcomes).to eq([ :hours_reported_compliant ])
      end
    end
  end

  # The defect this replaces: the previous design keyed off va_icn parity, which made
  # the demonstrated branch depend on what OTHER va_icn-keyed sources did at earlier
  # pipeline stages. Orthogonality is the invariant now, so assert it directly.
  describe "orthogonality to va_icn" do
    (0..9).each do |digit|
      it "emits the CE outcome regardless of va_icn last digit #{digit}" do
        cert = build(:certification, member_data: build(
          :certification_member_data,
          va_icn: "10000000#{digit}",
          account_email: "member+#{described_class::TRIGGER_EMAIL_SUBSTRING}@example.com"
        ))

        expect(described_class.new.call(certification: cert).outcomes).to eq([ :hours_reported_compliant ])
      end
    end

    it "emits no outcome for a triggerless email regardless of an odd va_icn" do
      cert = build(:certification, member_data: build(
        :certification_member_data, va_icn: "1000000007", account_email: "member@example.com"
      ))

      expect(described_class.new.call(certification: cert).outcomes).to eq([])
    end
  end
end
