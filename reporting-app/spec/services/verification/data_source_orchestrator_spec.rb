# frozen_string_literal: true

require "rails_helper"

RSpec.describe Verification::DataSourceOrchestrator do
  subject(:evaluate) { described_class.evaluate(certification) }

  # The orchestrator never inspects the certification itself; it hands it to each
  # source's #call. A double keeps the unit test off the DB/factories.
  let(:certification) { instance_double(Certification) }

  # Builds and registers a fake Verification::DataSource whose #call returns a
  # scripted DataSourceResult (or raises). Mirrors the stub_const(Class.new(...))
  # idiom in verification_data_sources_loader_spec.rb.
  def stub_source(const_name, result: nil, raises: nil)
    klass = Class.new(Verification::DataSource) do
      def self.declared_outcomes = [ :high_unemployment_county ]
    end
    klass.define_method(:call) do |certification:|
      raise raises if raises

      result
    end
    stub_const(const_name, klass)
    const_name
  end

  # stub_registry / registry_entry come from VerificationRegistryHelpers.

  def success(outcomes:, audit_data: {})
    Verification::DataSourceResult.success(outcomes: outcomes, audit_data: audit_data)
  end

  describe ".evaluate" do
    context "when an ordered source succeeds with a matched outcome" do
      before do
        stub_source("FirstSource", result: success(outcomes: [ :high_unemployment_county ], audit_data: { source: "first" }))
        stub_registry([ registry_entry(id: :first, adapter_class: "FirstSource", order: 10) ])
      end

      it "is satisfied and reports the producing source and its result" do
        expect(evaluate).to be_satisfied
        expect(evaluate).to have_attributes(
          satisfied: true,
          source_id: :first
        )
        expect(evaluate.result.outcomes).to eq([ :high_unemployment_county ])
        expect(evaluate.result.audit_data).to eq({ source: "first" })
      end
    end

    context "with several ordered sources" do
      it "calls them in ascending order and stops at the first success-with-outcome" do
        stub_source("LowOrder", result: success(outcomes: [ :high_unemployment_county ]))
        stub_source("HighOrder", result: success(outcomes: [ :inpatient_medical_care ]))
        stub_registry(
          [
            registry_entry(id: :high, adapter_class: "HighOrder", order: 20),
            registry_entry(id: :low, adapter_class: "LowOrder", order: 10)
          ]
        )

        # LowOrder (order 10) is evaluated first and wins; HighOrder is never reached.
        expect(evaluate.source_id).to eq(:low)
        expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :low ])
      end
    end

    context "when an ordered source succeeds with EMPTY outcomes" do
      it "does not stop and does not treat the empty success as satisfied" do
        stub_source("EmptySuccess", result: success(outcomes: []))
        stub_source("RealHit", result: success(outcomes: [ :high_unemployment_county ]))
        stub_registry(
          [
            registry_entry(id: :empty, adapter_class: "EmptySuccess", order: 10),
            registry_entry(id: :hit, adapter_class: "RealHit", order: 20)
          ]
        )

        expect(evaluate).to have_attributes(satisfied: true, source_id: :hit)
        expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :empty, :hit ])
      end
    end

    context "when earlier sources are skipped or errored" do
      it "continues past them, wins on a later source, and retains all attempts" do
        stub_source("Skipper", result: Verification::DataSourceResult.skipped(reason: :no_icn))
        stub_source("Errorer", result: Verification::DataSourceResult.error(error_code: :boom, error_message: "x", audit_data: {}))
        stub_source("Winner", result: success(outcomes: [ :high_unemployment_county ], audit_data: { source: "winner" }))
        stub_registry(
          [
            registry_entry(id: :skip, adapter_class: "Skipper", order: 10),
            registry_entry(id: :err, adapter_class: "Errorer", order: 20),
            registry_entry(id: :win, adapter_class: "Winner", order: 30)
          ]
        )

        expect(evaluate).to have_attributes(satisfied: true, source_id: :win)
        expect(evaluate.result.audit_data).to eq({ source: "winner" })
        expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :skip, :err, :win ])
        expect(evaluate.attempted.map { |a| a[:result].status }).to eq(%i[skipped error success])
      end
    end

    context "when a source is disabled" do
      it "does not call it even if its order would place it first" do
        stub_source("DisabledEarly", result: success(outcomes: [ :high_unemployment_county ]))
        stub_source("EnabledLater", result: success(outcomes: [ :inpatient_medical_care ]))
        stub_registry(
          [
            registry_entry(id: :disabled, adapter_class: "DisabledEarly", order: 5, enabled: false),
            registry_entry(id: :enabled, adapter_class: "EnabledLater", order: 10)
          ]
        )

        expect(evaluate.source_id).to eq(:enabled)
        expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :enabled ])
      end
    end

    context "when a source has a nil order (exclusion-only)" do
      it "is never included in the non-exclusion pass" do
        stub_source("ExclusionOnly", result: success(outcomes: [ :is_veteran_with_disability ]))
        stub_registry([ registry_entry(id: :exclusion, adapter_class: "ExclusionOnly", order: nil) ])

        expect(evaluate).to have_attributes(satisfied: false, source_id: nil)
        expect(evaluate.attempted).to be_empty
      end
    end

    context "when no ordered source succeeds with an outcome" do
      it "reports not satisfied while retaining the attempts" do
        stub_source("EmptyOne", result: success(outcomes: []))
        stub_source("SkippedOne", result: Verification::DataSourceResult.skipped)
        stub_registry(
          [
            registry_entry(id: :empty, adapter_class: "EmptyOne", order: 10),
            registry_entry(id: :skip, adapter_class: "SkippedOne", order: 20)
          ]
        )

        expect(evaluate).to have_attributes(satisfied: false, source_id: nil, result: nil)
        expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :empty, :skip ])
      end
    end

    context "with an empty ordered set" do
      it "reports not satisfied with no attempts" do
        stub_registry([])

        expect(evaluate).not_to be_satisfied
        expect(evaluate).to have_attributes(satisfied: false, source_id: nil)
        expect(evaluate.attempted).to be_empty
      end
    end

    context "when a source raises an unexpected error" do
      it "propagates rather than swallowing it (fail-loud, per DataSource#call)" do
        stub_source("Raiser", raises: RuntimeError.new("unexpected"))
        stub_registry([ registry_entry(id: :raiser, adapter_class: "Raiser", order: 10) ])

        expect { evaluate }.to raise_error(RuntimeError, "unexpected")
      end
    end
  end

  # Exercises the ACTUAL booted Rails.application.config.verification_data_sources
  # rather than a stubbed registry, so the registration in
  # config/custom/verification_data_sources.yml is proven end-to-end.
  describe "against the real registered configuration" do
    let(:certification) do
      build(:certification, member_data: build(
        :certification_member_data, va_icn: va_icn, account_email: account_email
      ))
    end
    let(:va_icn) { "1012861229V078998" }
    # Non-triggering by default; mock_community_engagement keys off the email, not the ICN.
    let(:account_email) { "member@example.com" }
    let(:ce_trigger_email) { "member+#{Verification::Adapters::MockCommunityEngagement::TRIGGER_EMAIL_SUBSTRING}@example.com" }

    # The shipped config ENABLES both demo mocks: no real non-exclusion source exists yet, so
    # they are what exercises this pass end to end in the test deployments. Both are
    # order-bearing; mock_drug_treatment is order: nil and belongs to the exclusion path, so it
    # is never part of this pass regardless.
    it "registers exactly the two demo mocks as the order-bearing pass, in order" do
      enabled_order_bearing = Rails.application.config.verification_data_sources
        .select { |e| e[:enabled] && !e[:order].nil? }
        .sort_by { |e| e[:order] }

      expect(enabled_order_bearing.map { |e| e[:id] })
        .to eq([ :mock_emergency_county, :mock_community_engagement ])
    end

    describe "the shipped demo mocks" do
      context "when the ICN's last digit is even" do
        let(:va_icn) { "1012861229V078998" }

        it "is satisfied by mock_emergency_county (order 10) with the exception outcome" do
          expect(evaluate).to have_attributes(satisfied: true, source_id: :mock_emergency_county)
          expect(evaluate.result.outcomes).to eq([ :resides_in_declared_emergency_county ])
        end
      end

      context "when the email carries the CE trigger and the ICN's last digit is not even" do
        let(:va_icn) { "1012861229V078999" }
        let(:account_email) { ce_trigger_email }

        # emergency-county returns no result for an odd digit, so the pass continues past it
        # to the community-engagement mock at order 20.
        it "falls through to mock_community_engagement with the CE-met outcome" do
          expect(evaluate).to have_attributes(satisfied: true, source_id: :mock_community_engagement)
          expect(evaluate.result.outcomes).to eq([ :hours_reported_compliant ])
          expect(evaluate.attempted.map { |a| a[:source_id] })
            .to eq([ :mock_emergency_county, :mock_community_engagement ])
        end
      end

      # The two shipped mocks read DIFFERENT fields, so an even digit reaches
      # mock_emergency_county first and stop-on-first ends the pass there — the CE trigger
      # in the email is never consulted. Locks in the precedence rather than leaving it to
      # registry order alone.
      context "when the email carries the CE trigger but the ICN's last digit is even" do
        let(:va_icn) { "1012861229V078998" }
        let(:account_email) { ce_trigger_email }

        it "stops at mock_emergency_county (order 10) without attempting the CE source" do
          expect(evaluate).to have_attributes(satisfied: true, source_id: :mock_emergency_county)
          expect(evaluate.attempted.map { |a| a[:source_id] }).to eq([ :mock_emergency_county ])
        end
      end

      context "when the member has neither an ICN nor an email (preconditions not met)" do
        let(:va_icn) { nil }
        let(:account_email) { nil }

        it "is not satisfied; every order-bearing source is attempted and skipped" do
          expect(evaluate).to have_attributes(satisfied: false, source_id: nil)
          expect(evaluate.attempted.map { |a| a[:result].status }).to all(eq(:skipped))
        end
      end
    end
  end
end
