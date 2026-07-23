# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExclusionDeterminationService do
  let(:service) { described_class }
  let(:cert_date) { Date.new(2025, 7, 1) }
  let(:member_data) { build(:certification_member_data, cert_date: cert_date) }

  describe '#determine' do
    let(:certification) do
      create(
        :certification,
        member_data: member_data,
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date)
      )
    end
    let(:kase) { create(:certification_case, certification_id: certification.id) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    # The single Determination recorded on the excluded path (nil when not excluded).
    def recorded_exclusion
      Determination.where(subject: certification, outcome: "excluded").order(created_at: :desc).first
    end

    context 'when a single exclusion applies' do
      context 'when the member is American Indian or Alaska Native' do
        let(:member_data) do
          build(:certification_member_data, race_ethnicity: "american_indian_or_alaska_native", cert_date: cert_date)
        end

        it 'publishes DeterminedExcluded and closes the case' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("closed")
        end

        it 'records the AIAN reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end

      context 'when the member is pregnant with a future due date (currently expecting)' do
        let(:member_data) { build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date + 3.months, cert_date:) }

        it 'records the pregnancy reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
        end
      end

      context 'when the member is pregnant with a parturition date within the prior 12 months (postpartum)' do
        let(:member_data) { build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date - 6.months, cert_date:) }

        it 'records the pregnancy reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
        end
      end

      context 'when the member is a veteran with a disability' do
        let(:member_data) { build(:certification_member_data, veteran_with_disability: true, cert_date: cert_date) }

        it 'records the veteran-disability reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end

      context 'when the member is a former foster care youth under 26' do
        let(:member_data) { build(:certification_member_data, was_in_foster_care: true, date_of_birth: cert_date - 20.years, cert_date:) }

        it 'records the former-foster-care reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "former_foster_care_excluded" ])
        end
      end

      context 'when the member is currently medically frail' do
        let(:member_data) { build(:certification_member_data, currently_medically_frail: true, cert_date:) }

        it 'records the medically-frail reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "medically_frail_excluded" ])
        end
      end

      context 'when the member is caretaking an infirm person during the certification month' do
        let(:member_data) { build(:certification_member_data, dates_caretaking_infirm: [ cert_date ], cert_date:) }

        it 'records the caretaker reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "caretaker_excluded" ])
        end
      end

      context 'when the member has a dependent child under 14' do
        let(:member_data) { build(:certification_member_data, dependent_children_birth_dates: [ cert_date - 5.years ], cert_date:) }

        it 'records the caretaker reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "caretaker_excluded" ])
        end
      end

      context 'when the member is meeting SNAP/TANF work requirements' do
        let(:member_data) { build(:certification_member_data, meeting_tanf_or_snap_work: true, cert_date:) }

        it 'records the tanf_snap_work reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "tanf_snap_work_excluded" ])
        end
      end

      context 'when the member is in drug/alcohol treatment during the certification month' do
        let(:member_data) { build(:certification_member_data, dates_in_drug_treatment: [ cert_date ], cert_date:) }

        it 'records the drug_treatment reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "drug_treatment_excluded" ])
        end
      end

      context 'when the member is incarcerated during the certification month' do
        let(:member_data) { build(:certification_member_data, dates_incarcerated: [ cert_date ], cert_date:) }

        it 'records the inmate reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "inmate_excluded" ])
        end
      end
    end

    context 'when multiple exclusions apply' do
      # Default priorities: is_american_indian_or_alaska_native (10) < is_veteran_with_disability (30) < is_pregnant (80).
      context 'when pregnant and a veteran with a disability' do
        let(:member_data) { build(:certification_member_data, veteran_with_disability: true, pregnancy_due_or_parturition_date: cert_date, cert_date:) }

        it 'records only the higher-priority veteran-disability exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end

      context 'when a former foster care youth and pregnant' do
        # former_foster_care (20) outranks is_pregnant (80)
        let(:member_data) do
          build(:certification_member_data, was_in_foster_care: true, date_of_birth: cert_date - 20.years, pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority former-foster-care exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "former_foster_care_excluded" ])
        end
      end

      context 'when medically frail and pregnant' do
        # medically_frail (40) outranks is_pregnant (80)
        let(:member_data) do
          build(:certification_member_data, currently_medically_frail: true, pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority medically-frail exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "medically_frail_excluded" ])
        end
      end

      context 'when a caretaker and pregnant' do
        # caretaker (50) outranks is_pregnant (80)
        let(:member_data) do
          build(:certification_member_data, dates_caretaking_infirm: [ cert_date ], pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority caretaker exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "caretaker_excluded" ])
        end
      end

      context 'when meeting SNAP/TANF work requirements and pregnant' do
        # tanf_snap_work (60) outranks is_pregnant (80)
        let(:member_data) do
          build(:certification_member_data, meeting_tanf_or_snap_work: true, pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority tanf_snap_work exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "tanf_snap_work_excluded" ])
        end
      end

      context 'when in drug/alcohol treatment and pregnant' do
        # drug_treatment (70) outranks is_pregnant (80)
        let(:member_data) do
          build(:certification_member_data, dates_in_drug_treatment: [ cert_date ], pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority drug_treatment exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "drug_treatment_excluded" ])
        end
      end

      context 'when incarcerated and pregnant' do
        # is_pregnant (80) outranks inmate (90), the lowest-priority exclusion
        let(:member_data) do
          build(:certification_member_data, dates_incarcerated: [ cert_date ], pregnancy_due_or_parturition_date: cert_date, cert_date:)
        end

        it 'records only the higher-priority pregnancy exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
        end
      end

      context 'when pregnant and American Indian or Alaska Native' do
        let(:member_data) do
          build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date, race_ethnicity: "american_indian_or_alaska_native", cert_date:)
        end

        it 'records only the higher-priority AIAN exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end

      context 'when all three exclusions apply' do
        let(:member_data) do
          build(:certification_member_data, veteran_with_disability: true, pregnancy_due_or_parturition_date: cert_date, race_ethnicity: "american_indian_or_alaska_native", cert_date:)
        end

        it 'records exactly one reason code — the highest priority (stop-at-first)' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end
    end

    context 'when the configured priority order is overridden' do
      # Re-rank so is_pregnant (10) outranks is_veteran_with_disability (20): proves selection
      # consults Exclusion.priority_order rather than a hardcoded order.
      before do
        allow(Rails.application.config).to receive(:exclusion_types).and_return(
          [
            { id: :is_pregnant, priority: 10 },
            { id: :is_veteran_with_disability, priority: 20 },
            { id: :is_american_indian_or_alaska_native, priority: 30 }
          ]
        )
      end

      let(:member_data) { build(:certification_member_data, veteran_with_disability: true, pregnancy_due_or_parturition_date: cert_date, cert_date:) }

      it 'records the exclusion now ranked highest (pregnancy)' do
        service.determine(kase)
        expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
      end
    end

    context 'when a matched exclusion is missing from the priority config' do
      # A fact evaluates true but no configured exclusion declares that fact —
      # exercises the fail-loud drift guard in exclusion_priority.
      before do
        allow(Rails.application.config).to receive(:exclusion_types).and_return(
          [ { id: :is_veteran_with_disability, priority: 30 } ]
        )
      end

      let(:member_data) { build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date, cert_date:) }

      it 'raises a descriptive error naming the unbridged fact' do
        expect { service.determine(kase) }.to raise_error(KeyError, /is_pregnant/)
      end
    end

    context 'when no exclusion applies' do
      context 'when the parturition date is more than 12 months before the certification date' do
        let(:member_data) { build(:certification_member_data, race_ethnicity: "white", pregnancy_due_or_parturition_date: cert_date - 13.months, cert_date:) }

        it 'publishes DeterminedNotExcluded and records no exclusion' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(recorded_exclusion).to be_nil
        end
      end

      context 'when a former foster care youth is 26 or older' do
        let(:member_data) { build(:certification_member_data, race_ethnicity: "white", was_in_foster_care: true, date_of_birth: cert_date - 30.years, cert_date:) }

        it 'publishes DeterminedNotExcluded and records no exclusion' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(recorded_exclusion).to be_nil
        end
      end

      context 'without any matching condition' do
        let(:member_data) { build(:certification_member_data, cert_date:) }

        it 'publishes DeterminedNotExcluded and leaves the case open' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("open")
        end

        it 'records no exclusion determination' do
          service.determine(kase)
          expect(recorded_exclusion).to be_nil
        end

        it 'logs a denied audit event' do
          expect { service.determine(kase) }
            .to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.exclusion.denied').count }.by(1)
        end
      end

      context 'when the member is not a veteran with a disability' do
        let(:member_data) { build(:certification_member_data, race_ethnicity: "white", veteran_with_disability: false, cert_date:) }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end
    end

    context 'when the member is outside the community-engagement age range' do
      context 'when under 19 with no other exclusion' do
        let(:member_data) { build(:certification_member_data, date_of_birth: cert_date - 18.years, race_ethnicity: "white", cert_date:) }

        it 'publishes DeterminedNotExcluded and leaves the case open' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("open")
        end
      end

      context 'when 65 or older with no other exclusion' do
        let(:member_data) { build(:certification_member_data, date_of_birth: cert_date - 65.years, race_ethnicity: "white", cert_date:) }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end
    end
  end

  # After the rules engine runs, the service consults the registered verification
  # data sources. A source is only called when the best exclusion it could emit
  # (the highest-priority Exclusion among its declared reason-code keys) could
  # outrank the exclusion the rules engine already found. When a called source
  # emits a higher-priority exclusion it wins; when the only surviving outcome is
  # an exception the service records it as an exception instead.
  describe '#determine consulting verification data sources' do
    let(:cert_date) { Date.new(2025, 7, 1) }
    let(:certification) do
      create(
        :certification,
        member_data: member_data,
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date)
      )
    end
    let(:kase) { create(:certification_case, certification_id: certification.id) }
    # Records which fixture sources actually had #call invoked (used to assert gating).
    let(:calls) { [] }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    def recorded_exclusion
      Determination.where(subject: certification, outcome: "excluded").order(created_at: :desc).first
    end

    def recorded_exception
      Determination.where(subject: certification, outcome: "excepted").order(created_at: :desc).first
    end

    # Anonymous Verification::DataSource subclass: declares `declared` outcome
    # keys and, when called, records the call and returns a success result
    # emitting `emits`. #call is overridden directly so tests need not set up a
    # precondition — the point under test is the service's call/gate decision.
    def fixture_source(declared:, emits:)
      recorder = calls
      Class.new(Verification::DataSource) do
        define_singleton_method(:declared_outcomes) { declared }
        define_method(:call) do |certification:|
          recorder << self.class.name
          Verification::DataSourceResult.success(outcomes: emits, audit_data: { source: self.class.name })
        end
      end
    end

    # Registers `sources` (Array of [const_name, klass, opts]) as the verification
    # data source registry for this example.
    def register(*sources)
      entries = sources.map do |name, klass, opts|
        stub_const(name, klass)
        { id: name.underscore.to_sym, enabled: opts.fetch(:enabled, true), adapter_class: name, order: opts[:order] }
      end
      allow(Rails.application.config).to receive(:verification_data_sources).and_return(entries)
    end

    context 'when a source cannot outrank the exclusion the rules engine found' do
      # Rules engine finds AIAN (priority 10); the source could at best emit
      # drug_treatment (priority 70), so it is never called.
      let(:member_data) { build(:certification_member_data, race_ethnicity: "american_indian_or_alaska_native", cert_date:) }

      before do
        register([ "LowerPotentialSource", fixture_source(declared: [ :drug_treatment ], emits: [ :drug_treatment ]), {} ])
      end

      it 'does not call the source' do
        service.determine(kase)
        expect(calls).to be_empty
      end

      it 'records the rules-engine exclusion' do
        service.determine(kase)
        expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
      end
    end

    context 'when a source can outrank the rules-engine exclusion and emits it' do
      # Rules engine finds pregnancy (80); the source's best declared exclusion, veteran-disability (30), outranks it.
      let(:member_data) { build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date, cert_date:) }

      before do
        register([ "VeteranSource", fixture_source(declared: [ :is_veteran_with_disability ], emits: [ :is_veteran_with_disability ]), {} ])
      end

      it 'calls the source and records its higher-priority exclusion' do
        service.determine(kase)
        expect(calls).to eq([ "VeteranSource" ])
        expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
      end
    end

    context 'when a source is called but emits nothing that outranks the rules engine' do
      let(:member_data) { build(:certification_member_data, pregnancy_due_or_parturition_date: cert_date, cert_date:) }

      before do
        register([ "VeteranSource", fixture_source(declared: [ :is_veteran_with_disability ], emits: []), {} ])
      end

      it 'keeps the rules-engine exclusion' do
        service.determine(kase)
        expect(calls).to eq([ "VeteranSource" ])
        expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
      end
    end

    context 'with two candidate sources' do
      # No rules-engine exclusion (white, no signals), so both sources are candidates.
      let(:member_data) { build(:certification_member_data, cert_date:) }

      context 'when the stronger source emits an outcome weaker than the second source could emit' do
        # source1 best declared AIAN (10) but emits medically_frail (40); source2 best declared veteran (30).
        # 40 is weaker than 30, so source2 is called and wins.
        before do
          register(
            [ "FirstSource", fixture_source(declared: [ :is_american_indian_or_alaska_native, :medically_frail ], emits: [ :medically_frail ]), {} ],
            [ "SecondSource", fixture_source(declared: [ :is_veteran_with_disability ], emits: [ :is_veteran_with_disability ]), {} ]
          )
        end

        it 'calls both sources and records the second source’s higher-priority exclusion' do
          service.determine(kase)
          expect(calls).to contain_exactly("FirstSource", "SecondSource")
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end

      context 'when the stronger source emits an outcome stronger than the second source could emit' do
        # source1 best declared AIAN (10), emits veteran (30); source2 best declared medically_frail (40).
        # 30 already beats 40, so source2 is never called.
        before do
          register(
            [ "FirstSource", fixture_source(declared: [ :is_american_indian_or_alaska_native, :is_veteran_with_disability ], emits: [ :is_veteran_with_disability ]), {} ],
            [ "SecondSource", fixture_source(declared: [ :medically_frail ], emits: [ :medically_frail ]), {} ]
          )
        end

        it 'records the first source’s exclusion without calling the second' do
          service.determine(kase)
          expect(calls).to eq([ "FirstSource" ])
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end
    end

    context 'when the only surviving outcome is an exception' do
      # No rules-engine exclusion; the source could emit drug_treatment (70) so it is
      # called, but it emits the exception outcome instead.
      let(:member_data) { build(:certification_member_data, cert_date:) }

      before do
        register([ "DrugTreatmentSource", fixture_source(declared: [ :drug_treatment, :was_in_drug_treatment ], emits: [ :was_in_drug_treatment ]), {} ])
      end

      it 'records an exception rather than an exclusion' do
        service.determine(kase)
        expect(recorded_exclusion).to be_nil
        expect(recorded_exception.reasons).to eq([ "drug_treatment_excepted" ])
      end

      it 'publishes DeterminedExcepted and closes the case' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
        expect(kase.reload.status).to eq("closed")
      end
    end

    context 'when a called source emits nothing at all' do
      let(:member_data) { build(:certification_member_data, cert_date:) }

      before do
        register([ "DrugTreatmentSource", fixture_source(declared: [ :drug_treatment ], emits: []), {} ])
      end

      it 'publishes DeterminedNotExcluded and records nothing' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        expect(recorded_exclusion).to be_nil
        expect(recorded_exception).to be_nil
      end
    end

    context 'when a source is disabled' do
      let(:member_data) { build(:certification_member_data, cert_date:) }

      before do
        register([ "DisabledSource", fixture_source(declared: [ :is_veteran_with_disability ], emits: [ :is_veteran_with_disability ]), { enabled: false } ])
      end

      it 'is never called' do
        service.determine(kase)
        expect(calls).to be_empty
        expect(recorded_exclusion).to be_nil
      end
    end

    context 'when a source declares no exclusion outcomes' do
      # An exception-only source declares no exclusion, so the exclusion check
      # never calls it — its exception is left for the external exception check.
      let(:member_data) { build(:certification_member_data, cert_date:) }

      before do
        register([ "ExceptionOnlySource", fixture_source(declared: [ :was_in_drug_treatment ], emits: [ :was_in_drug_treatment ]), {} ])
      end

      it 'is never called and yields no determination here' do
        service.determine(kase)
        expect(calls).to be_empty
        expect(recorded_exclusion).to be_nil
        expect(recorded_exception).to be_nil
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
      end
    end

    context 'with the real MockDrugTreatment data source' do
      let(:member_data) { build(:certification_member_data, va_icn: va_icn, cert_date:) }

      before do
        allow(Rails.application.config).to receive(:verification_data_sources).and_return(
          [ { id: :mock_drug_treatment, enabled: true, adapter_class: "Verification::Adapters::MockDrugTreatment", order: nil } ]
        )
      end

      context 'when the ICN is divisible by 3' do
        let(:va_icn) { "9" }

        it 'records the drug_treatment exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "drug_treatment_excluded" ])
        end
      end

      context 'when the ICN is odd and not divisible by 3' do
        let(:va_icn) { "7" }

        it 'records the drug_treatment exception' do
          service.determine(kase)
          expect(recorded_exception.reasons).to eq([ "drug_treatment_excepted" ])
        end
      end

      context 'when the ICN is even and not divisible by 3' do
        let(:va_icn) { "8" }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end

      context 'when the ICN is absent (source skipped)' do
        let(:va_icn) { nil }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end
    end
  end
end
