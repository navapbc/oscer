# frozen_string_literal: true

require "rails_helper"

# Mock verification data source used to demonstrate the dynamic data-source call
# in ExclusionDeterminationService. It derives its outcome purely from the LAST
# DIGIT of the member's va_icn, so specs can drive every branch deterministically:
#
#   * absent ICN                       -> :skipped (precondition not met)
#   * ICN not ending in a digit        -> :success, no outcomes ("no result")
#   * last digit divisible by 3        -> :success, [:drug_treatment]        (exclusion)
#   * last digit odd, not divisible by 3 -> :success, [:was_in_drug_treatment] (exception)
#   * last digit even, not divisible by 3 -> :success, no outcomes           (no result)
#
# Only the last digit matters, so "13" is excluded (last digit 3) while "12" is a
# no-result (last digit 2), even though 12 is the one divisible by 3 as a whole
# number. Outcomes are Determination::REASON_CODE_MAPPING keys (the "emit the
# key" convention): :drug_treatment maps to "drug_treatment_excluded" and
# :was_in_drug_treatment maps to "drug_treatment_excepted".
RSpec.describe Verification::Adapters::MockDrugTreatment do
  subject(:result) { described_class.new.call(certification: certification) }

  let(:certification) { build(:certification, member_data: build(:certification_member_data, va_icn: va_icn)) }

  describe ".declared_outcomes" do
    it "declares the exclusion and exception outcome keys" do
      expect(described_class.declared_outcomes).to contain_exactly(:drug_treatment, :was_in_drug_treatment)
    end

    it "declares only Determination reason-code mapping keys" do
      expect(described_class.declared_outcomes).to all(be_in(Determination::REASON_CODE_MAPPING.keys))
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
        expect(result.audit_data[:source]).to eq("mock_drug_treatment")
      end
    end

    context "when the last digit is divisible by 3" do
      context "when odd (e.g. '9')" do
        let(:va_icn) { "9" }

        it_behaves_like "a successful verification result"

        it "emits the drug_treatment exclusion outcome" do
          expect(result.outcomes).to eq([ :drug_treatment ])
        end
      end

      context "when zero (e.g. '10')" do
        let(:va_icn) { "10" }

        it "emits the drug_treatment exclusion outcome" do
          expect(result.outcomes).to eq([ :drug_treatment ])
        end
      end

      context "when the whole number is not divisible by 3 (e.g. '13')" do
        let(:va_icn) { "13" }

        it "emits the drug_treatment exclusion outcome (last digit 3)" do
          expect(result.outcomes).to eq([ :drug_treatment ])
        end
      end

      context "with a realistic VA ICN ending in a divisible-by-3 digit" do
        let(:va_icn) { "1012861229V078999" }

        it "emits the drug_treatment exclusion outcome (last digit 9)" do
          expect(result.outcomes).to eq([ :drug_treatment ])
        end
      end
    end

    context "when the last digit is odd and not divisible by 3" do
      context "with '7'" do
        let(:va_icn) { "7" }

        it_behaves_like "a successful verification result"

        it "emits the drug_treatment exception outcome" do
          expect(result.outcomes).to eq([ :was_in_drug_treatment ])
        end
      end

      context "with '25' (last digit 5)" do
        let(:va_icn) { "25" }

        it "emits the drug_treatment exception outcome" do
          expect(result.outcomes).to eq([ :was_in_drug_treatment ])
        end
      end
    end

    context "when the last digit is even and not divisible by 3" do
      context "with '8'" do
        let(:va_icn) { "8" }

        it_behaves_like "a successful verification result"

        it "returns no result (empty outcomes)" do
          expect(result.outcomes).to eq([])
        end
      end

      context "with '12', whose last digit is 2 even though 12 is divisible by 3" do
        let(:va_icn) { "12" }

        it "returns no result (empty outcomes)" do
          expect(result.outcomes).to eq([])
        end
      end
    end
  end
end
