# frozen_string_literal: true

require "rails_helper"

# +Strata::EventManager.publish+ is stubbed WITHOUT and_call_original (as in
# community_engagement_check_service_spec) so the business process never advances; this spec asserts
# what the service records and publishes in isolation.
RSpec.describe DataSourceCheckService do
  before do
    allow(Strata::EventManager).to receive(:publish)
    allow(NotificationService).to receive(:send_email_notification)
  end

  let(:certification) do
    create(:certification, member_data: build(
      :certification_member_data, va_icn: va_icn, account_email: account_email
    ))
  end
  let(:certification_case) { create(:certification_case, certification: certification) }
  let(:va_icn) { "1012861229V078998" }
  # Non-triggering by default; mock_community_engagement keys off the email, not the ICN.
  let(:account_email) { "member@example.com" }
  let(:ce_trigger_email) { "member+#{Verification::Adapters::MockCommunityEngagement::TRIGGER_EMAIL_SUBSTRING}@example.com" }

  # --- source doubles (stub_registry / registry_entry come from VerificationRegistryHelpers) ---

  # Stubs a source whose #call always returns the given result.
  def stub_source_returning(const_name, result, declared_outcomes:)
    klass = Class.new(Verification::DataSource) do
      define_singleton_method(:declared_outcomes) { declared_outcomes }
    end
    klass.define_method(:call) { |certification:| result }
    stub_const(const_name, klass)
    const_name
  end

  def stub_source(const_name, outcomes:)
    stub_source_returning(
      const_name,
      Verification::DataSourceResult.success(outcomes: outcomes, audit_data: { source: const_name }),
      declared_outcomes: outcomes
    )
  end

  def register_one(id:, outcomes:, order: 10)
    const_name = "Stub#{id.to_s.camelize}Source"
    stub_source(const_name, outcomes: outcomes)
    stub_registry([ registry_entry(id: id, adapter_class: const_name, order: order) ])
  end

  def register_erroring(id:, error_code: :read_timeout, order: 10)
    const_name = stub_source_returning(
      "Stub#{id.to_s.camelize}Source",
      Verification::DataSourceResult.error(
        error_code: error_code, error_message: "upstream unavailable", audit_data: {}
      ),
      declared_outcomes: [ :was_inmate ]
    )
    stub_registry([ registry_entry(id: id, adapter_class: const_name, order: order) ])
  end

  def create_external_hourly_activity_for(certification, hours:)
    lookback = certification.certification_requirements.continuous_lookback_period
    create(:external_activity, :with_hours,
      member_id: certification.member_id,
      period_start: lookback.start.to_date,
      period_end: lookback.start.to_date.end_of_month,
      hours: hours)
  end

  def latest_determination
    latest_determination_for(certification.id)
  end

  describe ".determine" do
    context "when a source emits an exception outcome" do
      before do
        register_one(id: :emergency_feed, outcomes: [ :resides_in_declared_emergency_county ])
      end

      it "records an excepted determination carrying the producing source id" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("excepted")
        expect(latest_determination.reasons).to eq([ "declared_emergency_county_excepted" ])
        expect(latest_determination.determination_data["data_source"]).to eq("emergency_feed")
        expect(latest_determination.source).to eq("emergency_feed")
      end

      it "closes the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_closed
      end

      it "publishes DeterminedExcepted" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedExcepted",
          hash_including(case_id: certification_case.id)
        )
      end

      it "publishes no community-engagement events" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).not_to have_received(:publish).with(
          a_string_matching(/CommunityEngagement/), anything
        )
      end

      it "writes the exception audit line derived from the excepted outcome" do
        expect do
          described_class.determine(certification_case)
        end.to change {
          Strata::AuditLine.where(
            subject: certification,
            actor_type: described_class.name,
            action: "case.exception.approved"
          ).count
        }.by(1)
      end
    end

    context "when a source attests community engagement is met" do
      before do
        register_one(id: :workforce_feed, outcomes: [ :hours_reported_compliant ])
      end

      it "records a compliant determination under the source-attested CE calculation type" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("compliant")
        expect(latest_determination.reasons).to eq([ "hours_reported_compliant" ])
        expect(latest_determination.determination_data["calculation_type"])
          .to eq(Determination::CALCULATION_TYPE_DATA_SOURCE_CE)
      end

      it "carries the producing source id as the determination source" do
        described_class.determine(certification_case)

        expect(latest_determination.determination_data["data_source"]).to eq("workforce_feed")
        expect(latest_determination.source).to eq("workforce_feed")
      end

      it "does NOT record the in-hand external-CE-combined shape" do
        described_class.determine(certification_case)

        # The source attests the requirement is met; it reports no hours. Recording
        # the combined shape would assert an in-hand hours/income result.
        expect(latest_determination.determination_data.keys).to contain_exactly("calculation_type", "data_source")
      end

      it "closes the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_closed
      end

      it "publishes DeterminedCommunityEngagementMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementMet",
          hash_including(case_id: certification_case.id)
        )
      end

      it "writes the approved audit line derived from the compliant outcome" do
        expect do
          described_class.determine(certification_case)
        end.to change {
          Strata::AuditLine.where(
            subject: certification,
            actor_type: described_class.name,
            action: "case.activity_report.approved"
          ).count
        }.by(1)
      end
    end

    context "when a source emits several exception outcomes" do
      before do
        register_one(id: :multi_feed, outcomes: [ :receiving_inpatient_medical_care, :was_inmate ])
      end

      # Registered in reverse of Determination::EXCEPTION_OUTCOME_KEYS order on purpose: only a
      # reversed pair tells "the source's order decides" apart from "the canonical order decides".
      it "records only the first exception reason code the source emitted" do
        described_class.determine(certification_case)

        expect(latest_determination.reasons).to eq([ "inpatient_medical_care_excepted" ])
      end
    end

    context "when a source emits both community-engagement outcomes" do
      before do
        register_one(id: :combined_feed, outcomes: [ :hours_reported_compliant, :income_reported_compliant ])
      end

      it "records both compliant reason codes on one determination" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("compliant")
        expect(latest_determination.reasons).to contain_exactly(
          "hours_reported_compliant",
          "income_reported_compliant"
        )
      end
    end

    context "when a source emits both an exception and a community-engagement outcome" do
      before do
        register_one(id: :hybrid_feed, outcomes: [ :hours_reported_compliant, :was_inmate ])
      end

      # Precedence: an exception excuses the member for the period regardless of
      # activity levels, and the flow itself checks exceptions before CE.
      it "records the exception and ignores the community-engagement outcome" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("excepted")
        expect(latest_determination.reasons).to eq([ "inmate_excepted" ])
      end

      it "publishes DeterminedExcepted, not DeterminedCommunityEngagementMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with("DeterminedExcepted", anything)
        expect(Strata::EventManager).not_to have_received(:publish).with(
          "DeterminedCommunityEngagementMet", anything
        )
      end

      it "records exactly one determination" do
        expect do
          described_class.determine(certification_case)
        end.to change { Determination.unscope(:order).where(subject_id: certification.id).count }.by(1)
      end
    end

    # Defense in depth, not the primary guard: an order-bearing source declaring an
    # uncategorized outcome now fails at boot (VerificationDataSourcesLoader), and a source
    # returning an outcome it did not declare raises ContractError in
    # Verification::DataSource#call. This asserts the service still refuses to misfile if a
    # result reaches it anyway.
    context "when a source emits an outcome in neither whitelist" do
      before do
        # A valid REASON_CODE_MAPPING key with no determination shape on this path.
        register_one(id: :rogue_feed, outcomes: [ :exemption_request_compliant ])
      end

      it "raises rather than misfiling the outcome" do
        expect do
          described_class.determine(certification_case)
        end.to raise_error(DataSourceCheckService::UnsupportedOutcomeError, /exemption_request_compliant/)
      end

      it "records no determination" do
        expect do
          described_class.determine(certification_case)
        rescue DataSourceCheckService::UnsupportedOutcomeError
          nil
        end.not_to change { Determination.unscope(:order).where(subject_id: certification.id).count }
      end
    end

    # The negative determination is OWNED BY THIS STEP, not the community-engagement
    # check. The CE check computes met-vs-not-met and defers finalizing the negative,
    # so a member later excepted or attested-compliant by a source never accumulates
    # a superseded not_compliant row (nor its "case.activity_report.denied" audit
    # line). Exactly one determination is written per member, after all evidence is in.
    context "when no source produces an outcome and external hours exist" do
      before do
        register_one(id: :quiet_feed, outcomes: [])
        create_external_hourly_activity_for(certification, hours: 40)
      end

      it "publishes Insufficient with the hours and income payload" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementInsufficient",
          hash_including(
            case_id: certification_case.id,
            hours_data: kind_of(Hash),
            income_data: kind_of(Hash)
          )
        )
      end

      it "records the not_compliant combined-CE determination, as the CE check used to" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("not_compliant")
        expect(latest_determination.reasons).to contain_exactly(
          "hours_reported_insufficient",
          "income_reported_insufficient"
        )
        data = latest_determination.determination_data
        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED)
        expect(data["satisfied_by"]).to eq(Determination::SATISFIED_BY_NEITHER)
      end

      it "records exactly one determination" do
        expect do
          described_class.determine(certification_case)
        end.to change { Determination.unscope(:order).where(subject_id: certification.id).count }.by(1)
      end

      it "writes the denied audit line here rather than at the CE check" do
        expect do
          described_class.determine(certification_case)
        end.to change {
          Strata::AuditLine.where(
            subject: certification,
            actor_type: described_class.name,
            action: "case.activity_report.denied"
          ).count
        }.by(1)
      end

      it "leaves the case open" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_open
      end
    end

    context "when no source produces an outcome and there are no external hours" do
      before do
        register_one(id: :quiet_feed, outcomes: [])
      end

      it "publishes ActionRequired" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end

      it "records the not_compliant combined-CE determination" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("not_compliant")
        expect(latest_determination.determination_data["satisfied_by"])
          .to eq(Determination::SATISFIED_BY_NEITHER)
      end
    end

    # Documents a KNOWN GAP, tracked by https://github.com/navapbc/oscer/issues/810: an errored
    # source is indistinguishable from "no outcome" to the orchestrator, so a member is recorded
    # non-compliant even though a source that might have excepted them was never reached. Before
    # this step existed the orchestrator was inert, so the gap had no member-facing consequence;
    # it does now. Until #810 lands, the failure is at least surfaced in the log rather than
    # silently indistinguishable from a clean negative.
    context "when a source errors rather than returning an outcome" do
      before { register_erroring(id: :flaky_feed) }

      it "still records non-compliance for the member (the #810 gap, pinned deliberately)" do
        described_class.determine(certification_case)

        expect(latest_determination.outcome).to eq("not_compliant")
      end

      it "logs a warning naming the failed source and its error code" do
        allow(Rails.logger).to receive(:warn)

        described_class.determine(certification_case)

        expect(Rails.logger).to have_received(:warn).with(
          a_string_matching(/flaky_feed=read_timeout/)
        )
      end
    end

    context "when every source produces an outcome-free success" do
      before { register_one(id: :quiet_feed, outcomes: []) }

      it "does not log a source-failure warning" do
        allow(Rails.logger).to receive(:warn)

        described_class.determine(certification_case)

        expect(Rails.logger).not_to have_received(:warn)
      end
    end

    context "when no order-bearing sources are registered" do
      before { stub_registry([]) }

      # Production-parity case: with both demo mocks disabled the registry has no
      # order-bearing sources, so this step records and publishes exactly what the
      # community-engagement check did before Phase C.
      it "records the negative determination and publishes ActionRequired" do
        expect do
          described_class.determine(certification_case)
        end.to change { Determination.unscope(:order).where(subject_id: certification.id).count }.by(1)

        expect(latest_determination.outcome).to eq("not_compliant")
        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "with the real MockEmergencyCounty registered" do
      before do
        stub_registry(
          [
            registry_entry(
              id: :mock_emergency_county,
              adapter_class: "Verification::Adapters::MockEmergencyCounty",
              order: 10
            )
          ]
        )
      end

      context "when the member's va_icn ends in an even digit" do
        let(:va_icn) { "1012861229V078998" }

        it "records an excepted determination sourced to the mock" do
          described_class.determine(certification_case)

          expect(latest_determination.outcome).to eq("excepted")
          expect(latest_determination.source).to eq("mock_emergency_county")
        end
      end

      context "when the member's va_icn ends in an odd digit" do
        let(:va_icn) { "1012861229V078999" }

        it "records the negative determination and routes the member to report activities" do
          described_class.determine(certification_case)

          expect(latest_determination.outcome).to eq("not_compliant")
          expect(Strata::EventManager).to have_received(:publish).with(
            "DeterminedCommunityEngagementActionRequired",
            hash_including(case_id: certification_case.id)
          )
        end
      end
    end

    context "with the real MockCommunityEngagement registered" do
      before do
        stub_registry(
          [
            registry_entry(
              id: :mock_community_engagement,
              adapter_class: "Verification::Adapters::MockCommunityEngagement",
              order: 20
            )
          ]
        )
      end

      # Keys off the email, not the va_icn, so it stays orthogonal to every va_icn-keyed
      # source and cannot be starved by one at an earlier pipeline stage.
      context "when the member's email carries the CE trigger" do
        let(:account_email) { ce_trigger_email }

        it "records a source-attested compliant determination" do
          described_class.determine(certification_case)

          expect(latest_determination.outcome).to eq("compliant")
          expect(latest_determination.determination_data["calculation_type"])
            .to eq(Determination::CALCULATION_TYPE_DATA_SOURCE_CE)
          expect(latest_determination.source).to eq("mock_community_engagement")
        end
      end

      context "when the member's email does not carry the CE trigger" do
        let(:account_email) { "member@example.com" }

        it "attests nothing, so the negative determination is recorded" do
          described_class.determine(certification_case)

          expect(latest_determination.outcome).to eq("not_compliant")
        end
      end

      context "when the member has no email at all" do
        let(:account_email) { nil }

        it "skips the source, so the negative determination is recorded" do
          described_class.determine(certification_case)

          expect(latest_determination.outcome).to eq("not_compliant")
        end
      end
    end
  end
end
