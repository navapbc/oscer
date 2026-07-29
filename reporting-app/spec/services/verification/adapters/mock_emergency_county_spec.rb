# frozen_string_literal: true

require "rails_helper"

# Mock verification data source used to demonstrate the ordered non-exclusion
# pass in Verification::DataSourceOrchestrator (OSCER-805). Like
# Verification::Adapters::MockDrugTreatment, it derives its outcome purely from
# the LAST DIGIT of the member's va_icn, so specs can drive every branch
# deterministically:
#
#   * absent ICN                 -> :skipped (precondition not met)
#   * ICN not ending in a digit  -> :success, no outcomes ("no result")
#   * last digit even            -> :success, [:resides_in_declared_emergency_county]
#   * last digit odd             -> :success, no outcomes ("no result")
#
# va_icn is an unrelated identity field, chosen (as in MockDrugTreatment) so the
# outcome is a deterministic function of a single always-present scalar. Keying
# off an unrelated field also keeps the demo honest: it does NOT re-read
# dates_in_declared_emergency_county, the in-hand field ExceptionDeterminationService
# already evaluates, so it stands in for an *external* source rather than
# duplicating the in-hand check.
#
# The single outcome :resides_in_declared_emergency_county is a
# Determination::REASON_CODE_MAPPING key (the "emit the key" convention) that is
# not an exclusion id, so this source is order-bearing (non-exclusion) and is
# consulted only by the orchestrator, never by ExclusionDeterminationService.
RSpec.describe Verification::Adapters::MockEmergencyCounty do
  subject(:result) { described_class.new.call(certification: certification) }

  let(:certification) { build(:certification, member_data: build(:certification_member_data, va_icn: va_icn)) }

  describe ".declared_outcomes" do
    it "declares the emergency-county exception outcome key" do
      expect(described_class.declared_outcomes).to contain_exactly(:resides_in_declared_emergency_county)
    end

    it "declares only Determination reason-code mapping keys" do
      expect(described_class.declared_outcomes).to all(be_in(Determination::REASON_CODE_MAPPING.keys))
    end

    it "declares only non-exclusion (order-bearing) outcome keys" do
      expect(described_class.declared_outcomes).to all(satisfy { |key| Exclusion.find(key).nil? })
    end
  end

  describe "#call" do
    context "when the ICN is absent" do
      let(:va_icn) { nil }

      it_behaves_like "a skipped verification result"
    end

    context "when the ICN is a blank string" do
      let(:va_icn) { "" }

      it_behaves_like "a skipped verification result"
    end

    context "when the ICN does not end in a digit (e.g. '12345V')" do
      let(:va_icn) { "12345V" }

      it_behaves_like "a successful verification result"

      it "returns no result (empty outcomes)" do
        expect(result.outcomes).to eq([])
      end

      it "tags the audit data with the source" do
        expect(result.audit_data[:source]).to eq("mock_emergency_county")
      end
    end

    context "when the last digit is even" do
      context "with '4'" do
        let(:va_icn) { "4" }

        it_behaves_like "a successful verification result"

        it "emits the emergency-county exception outcome" do
          expect(result.outcomes).to eq([ :resides_in_declared_emergency_county ])
        end
      end

      context "with '0' (zero is even)" do
        let(:va_icn) { "10" }

        it "emits the emergency-county exception outcome" do
          expect(result.outcomes).to eq([ :resides_in_declared_emergency_county ])
        end
      end

      context "with a realistic VA ICN ending in an even digit" do
        let(:va_icn) { "1012861229V078998" }

        it "emits the emergency-county exception outcome (last digit 8)" do
          expect(result.outcomes).to eq([ :resides_in_declared_emergency_county ])
        end
      end
    end

    context "when the last digit is odd" do
      context "with '7'" do
        let(:va_icn) { "7" }

        it_behaves_like "a successful verification result"

        it "returns no result (empty outcomes)" do
          expect(result.outcomes).to eq([])
        end
      end

      context "with a realistic VA ICN ending in an odd digit" do
        let(:va_icn) { "1012861229V078999" }

        it "returns no result (empty outcomes, last digit 9)" do
          expect(result.outcomes).to eq([])
        end
      end
    end
  end
end
