# frozen_string_literal: true

require "rails_helper"

RSpec.describe Verification::DataSource do
  let(:certification) { instance_double(Certification) }

  before do
    stub_const("TestVerificationApiError", Class.new(StandardError))
    stub_const("TestUndeclaredError", Class.new(StandardError))

    stub_const("TestDataSource", Class.new(described_class) do
      def self.declared_outcomes
        [ :matched ]
      end

      def initialize(precondition: true, behavior: :success_empty)
        @precondition = precondition
        @behavior = behavior
      end

      protected

      def precondition_met?(_certification)
        @precondition
      end

      def perform(certification:)
        case @behavior
        when :success_empty then success_result(outcomes: [], audit_data: { called: true })
        when :success_populated then success_result(outcomes: [ :matched ], audit_data: { called: true })
        when :raise_expected then raise TestVerificationApiError, "integration down"
        when :raise_undeclared then raise TestUndeclaredError, "boom"
        when :return_nil then nil
        end
      end

      def expected_error_classes
        [ TestVerificationApiError ]
      end
    end)
  end

  describe ".declared_outcomes" do
    it "raises NotImplementedError on the abstract base" do
      expect { described_class.declared_outcomes }.to raise_error(NotImplementedError)
    end
  end

  describe "#call" do
    subject(:result) { data_source.call(certification: certification) }

    context "when a precondition is missing" do
      let(:data_source) { TestDataSource.new(precondition: false) }

      it_behaves_like "a skipped verification result"
    end

    context "when the source succeeds with no matching outcome" do
      let(:data_source) { TestDataSource.new(behavior: :success_empty) }

      it_behaves_like "a successful verification result"

      it "has empty outcomes and populated audit_data" do
        expect(result.outcomes).to eq([])
        expect(result.audit_data).to eq(called: true)
      end
    end

    context "when the source succeeds with a matching outcome" do
      let(:data_source) { TestDataSource.new(behavior: :success_populated) }

      it_behaves_like "a successful verification result"

      it "exposes the emitted outcome" do
        expect(result.outcomes).to eq([ :matched ])
      end
    end

    context "when the source hits an expected integration failure" do
      let(:data_source) { TestDataSource.new(behavior: :raise_expected) }

      it_behaves_like "an errored verification result"
      it_behaves_like "a resilient verification data source"

      it "maps the error class to an error_code" do
        expect(result.error_code).to eq(:test_verification_api_error)
        expect(result.error_message).to eq("integration down")
      end
    end

    context "when the source raises an undeclared error" do
      let(:data_source) { TestDataSource.new(behavior: :raise_undeclared) }

      it "propagates the error rather than swallowing it" do
        expect { result }.to raise_error(TestUndeclaredError, "boom")
      end
    end

    context "when #perform violates the contract by returning nil" do
      let(:data_source) { TestDataSource.new(behavior: :return_nil) }

      it "raises ContractError" do
        expect { result }.to raise_error(Verification::DataSource::ContractError, /must return/)
      end
    end

    context "when a subclass declares an over-broad expected_error_classes" do
      let(:data_source) do
        Class.new(described_class) do
          def precondition_met?(_certification) = true
          def perform(certification:) = nil
          def expected_error_classes = [ StandardError ]
        end.new
      end

      it "still raises ContractError rather than swallowing it as an :error result" do
        expect { result }.to raise_error(Verification::DataSource::ContractError, /must return/)
      end
    end
  end

  describe "abstract hooks" do
    let(:bare_source) { Class.new(described_class).new }

    it "requires subclasses to implement #precondition_met?" do
      expect { bare_source.call(certification: certification) }
        .to raise_error(NotImplementedError, /precondition_met\?/)
    end

    it "requires subclasses to implement #perform" do
      klass = Class.new(described_class) do
        def precondition_met?(_certification) = true
      end

      expect { klass.new.call(certification: certification) }
        .to raise_error(NotImplementedError, /perform/)
    end
  end
end
