# frozen_string_literal: true

require "rails_helper"

RSpec.describe Verification::DataSourceResult do
  describe ".skipped" do
    subject(:result) { described_class.skipped }

    it_behaves_like "a skipped verification result"

    it "defaults to empty audit_data" do
      expect(result.audit_data).to eq({})
    end

    it "records a skip reason under audit_data when given" do
      result = described_class.skipped(reason: :missing_icn)

      expect(result.audit_data).to eq(skip_reason: :missing_icn)
    end

    it "merges an explicit skip reason into provided audit_data" do
      result = described_class.skipped(reason: :missing_icn, audit_data: { checked_at: "t" })

      expect(result.audit_data).to eq(checked_at: "t", skip_reason: :missing_icn)
    end
  end

  describe ".success" do
    context "with an empty outcome set" do
      subject(:result) { described_class.success(audit_data: { rating: 70 }) }

      it_behaves_like "a successful verification result"

      it "allows empty outcomes (called, no matching outcome)" do
        expect(result.outcomes).to eq([])
      end

      it "keeps the provided audit_data" do
        expect(result.audit_data).to eq(rating: 70)
      end
    end

    context "with a populated outcome set" do
      subject(:result) do
        described_class.success(outcomes: [ :veteran_with_disability ], audit_data: { rating: 100 })
      end

      it_behaves_like "a successful verification result"

      it "exposes the emitted outcomes" do
        expect(result.outcomes).to eq([ :veteran_with_disability ])
      end
    end

    it "requires audit_data" do
      expect { described_class.success(outcomes: []) }.to raise_error(ArgumentError)
    end
  end

  describe ".error" do
    subject(:result) do
      described_class.error(
        error_code: :unauthorized,
        error_message: "VA API unauthorized",
        audit_data: { attempted_at: "t" }
      )
    end

    it_behaves_like "an errored verification result"

    it "exposes the error code and message" do
      expect(result.error_code).to eq(:unauthorized)
      expect(result.error_message).to eq("VA API unauthorized")
    end

    it "requires audit_data" do
      expect { described_class.error(error_code: :x, error_message: "y") }.to raise_error(ArgumentError)
    end
  end

  describe "validation" do
    it "rejects an unknown status" do
      expect { described_class.send(:build, status: :bogus, audit_data: {}) }
        .to raise_error(ActiveModel::ValidationError)
    end

    it "rejects non-symbol outcomes" do
      expect { described_class.success(outcomes: [ "not_a_symbol" ], audit_data: {}) }
        .to raise_error(ActiveModel::ValidationError)
    end
  end

  describe "immutability" do
    subject(:result) { described_class.success(outcomes: [ :a ], audit_data: { k: 1 }) }

    it "freezes outcomes" do
      expect(result.outcomes).to be_frozen
    end

    it "freezes audit_data" do
      expect(result.audit_data).to be_frozen
    end
  end

  describe "status predicates" do
    it "reports each status distinctly" do
      expect(described_class.skipped).to be_skipped
      expect(described_class.success(audit_data: {})).to be_success
      expect(described_class.error(error_code: :x, error_message: "y", audit_data: {})).to be_error
    end
  end
end
