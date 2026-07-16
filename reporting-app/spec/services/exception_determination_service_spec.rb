# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExceptionDeterminationService do
  let(:service) { described_class }
  let(:certification) { create(:certification) }
  let(:kase) { create(:certification_case, certification_id: certification.id) }

  before do
    allow(Strata::EventManager).to receive(:publish)
    allow(NotificationService).to receive(:send_email_notification)
  end

  # Each check's member data is set up in its own context; these shared examples assert the common
  # excepted / not-excepted outcomes.
  shared_examples 'an applied external exception' do |reason_code|
    it 'records an excepted determination carrying the reason code' do
      expect { service.determine(kase) }.to change {
        Determination.where(subject: certification, outcome: 'excepted').count
      }.by(1)

      determination = Determination.where(subject: certification, outcome: 'excepted').first
      expect(determination.reasons).to eq([ reason_code ])
    end

    it 'closes the case' do
      service.determine(kase)
      expect(kase.reload.status).to eq('closed')
    end

    it 'publishes DeterminedExcepted' do
      service.determine(kase)
      expect(Strata::EventManager).to have_received(:publish)
        .with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
    end
  end

  shared_examples 'a failed check' do
    it 'does not except the member (publishes DeterminedNotExcepted)' do
      service.determine(kase)
      expect(Strata::EventManager).to have_received(:publish)
        .with('DeterminedNotExcepted', { case_id: kase.id, certification_id: kase.certification_id })
    end

    it 'does not record an exception determination' do
      expect { service.determine(kase) }.not_to change {
        Determination.where(subject: certification, outcome: 'excepted').count
      }
    end
  end

  shared_examples 'a disabled optional exception' do |exception_id|
    before do
      # Default to the real config, then disable only the exception under test, so the checks that
      # run before it (up to the first success) still consult real enablement.
      allow(ExternalException).to receive(:enabled?).and_call_original
      allow(ExternalException).to receive(:enabled?).with(exception_id).and_return(false)
    end

    it_behaves_like 'a failed check'
  end

  shared_examples 'a disabled mandatory exception' do |exception_id|
    before do
      # Default to the real config, then disable only the exception under test, so the checks that
      # run before it (up to the first success) still consult real enablement.
      allow(ExternalException).to receive(:enabled?).and_call_original
      allow(ExternalException).to receive(:enabled?).with(exception_id).and_return(false)
    end

    it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
  end

  shared_examples 'an optional exception' do |attribute, exception_id|
    let(:member_data) { build(:certification_member_data, cert_date:, attribute => event_date) }

    context 'when event in month that can be certified' do
      let(:event_date) { [ cert_date - 2.months - 2.days ] }

      it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
      it_behaves_like 'a disabled optional exception', exception_id
    end

    context 'when event not in month that can be certified' do
      let(:event_date) { [ cert_date - 3.months - 2.days ] }

      it_behaves_like 'a failed check'
    end

    context 'with invalid data' do
      let(:event_date) { [ 'not a date' ] }

      it_behaves_like 'a failed check'
    end
  end

  shared_examples 'a mandatory exception' do |exception_id|
    context 'when event in month that can be certified' do
      it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
      it_behaves_like 'a disabled mandatory exception', exception_id
    end

    context 'when event not in month that can be certified' do
      let(:months_that_can_be_certified) { (0..2).map { |i| cert_date - i.month } }

      it_behaves_like 'a failed check'
    end
  end

  describe '#determine' do
    let(:cert_date) { Date.new(2025, 7, 1) }
    let(:member_data) { build(:certification_member_data, cert_date:) }
    let(:months_that_can_be_certified) { (0..3).map { |i| cert_date - i.month } }
    let(:certification) do
      create(
        :certification,
        member_data:,
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date, months_that_can_be_certified:)
      )
    end

    context 'when no exception check applies (member data carries no exception signals)' do
      it_behaves_like 'a failed check'

      it 'logs a denied event in the audit log' do
        expect do
          service.determine(kase)
        end.to change {
          Strata::AuditLine.where(
            subject: certification,
            actor_type: described_class.name,
            action: 'case.exception.denied'
          ).count
        }.by(1)
      end

      it 'does not record an exception determination' do
        allow(kase).to receive(:record_exception_determination)
        service.determine(kase)
        expect(kase).not_to have_received(:record_exception_determination)
      end
    end

    context 'when applicant was under 19 years old' do
      let(:date_of_birth) { cert_date - (19.years + 2.months + 5.days) }
      let(:member_data) { build(:certification_member_data, cert_date:, date_of_birth:) }

      it_behaves_like 'a mandatory exception', :age_under_19
    end

    describe 'checking participating-in-other-program' do
      let(:event_date) { [ cert_date - 2.months - 2.days ] }
      let(:member_data) { build(:certification_member_data, cert_date:, dates_participating_in_other_program: event_date) }

      it_behaves_like 'a mandatory exception', :other_program

      context 'with invalid data' do
        let(:event_date) { [ 'not a date' ] }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking pregnancy' do
      let(:member_data) { build(:certification_member_data, cert_date:, pregnancy_due_or_parturition_date:) }

      context 'when the postpartum window covers a certifiable month' do
        # postpartum window ends cert_date - 1.month, inside the certifiable window
        let(:pregnancy_due_or_parturition_date) { cert_date - 13.months }

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when within the postpartum window but it extends past the certifiable window' do
        # gave birth cert_date - 1.month, so the postpartum window ends ~11 months after cert_date
        # (past every certifiable month), yet the member was within it during each certifiable month.
        # A currently-pregnant/postpartum member would normally qualify as an exemption and not reach
        # the exception check; this covers it defensively.
        let(:pregnancy_due_or_parturition_date) { cert_date - 1.month }

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when the postpartum window ended before every certifiable month' do
        # postpartum window ends cert_date - 4.months, before the earliest certifiable month
        let(:pregnancy_due_or_parturition_date) { cert_date - 16.months }

        it_behaves_like 'a failed check'
      end

      context 'when there is no pregnancy/parturition date' do
        let(:pregnancy_due_or_parturition_date) { nil }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking former foster care' do
      let(:member_data) { build(:certification_member_data, cert_date:, was_in_foster_care:, date_of_birth:) }

      context 'when a former foster youth is under the age cap during a certifiable month' do
        let(:was_in_foster_care) { true }
        let(:date_of_birth) { cert_date - (25.years + 2.months) } # ~25 -> under 26

        it_behaves_like 'an applied external exception', 'was_former_foster_care'
      end

      context 'when a former foster youth is at/over the age cap in every certifiable month' do
        let(:was_in_foster_care) { true }
        let(:date_of_birth) { cert_date - 27.years } # 27 -> over 26 throughout

        it_behaves_like 'a failed check'
      end

      context 'when a former foster youth turns 26 mid-way through the earliest certifiable month' do
        let(:was_in_foster_care) { true }
        # 26th birthday is the 16th of the earliest certifiable month; still under 26 at its start
        let(:date_of_birth) { cert_date - 26.years - 3.months + 15.days }

        it_behaves_like 'an applied external exception', 'was_former_foster_care'
      end

      context 'when a former foster youth turns 26 on the first of the earliest certifiable month' do
        let(:was_in_foster_care) { true }
        # 26th birthday is the 1st of the earliest certifiable month; already 26 at its start
        let(:date_of_birth) { cert_date - 26.years - 3.months }

        it_behaves_like 'a failed check'
      end

      context 'when the member was not in foster care' do
        let(:was_in_foster_care) { false }
        let(:date_of_birth) { cert_date - (25.years + 2.months) }

        it_behaves_like 'a failed check'
      end

      context 'when there is no date of birth' do
        let(:was_in_foster_care) { true }
        let(:date_of_birth) { nil }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking caretaker' do
      let(:member_data) do
        build(:certification_member_data, cert_date:, dates_caretaking_infirm:, dependent_children_birth_dates:)
      end
      let(:dates_caretaking_infirm) { [] }
      let(:dependent_children_birth_dates) { [] }

      context 'when caretaking an infirm person during a certifiable month' do
        let(:dates_caretaking_infirm) { [ cert_date - 2.months ] }

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when caretaking an infirm person only outside the certifiable months' do
        let(:dates_caretaking_infirm) { [ cert_date - 6.months ] }

        it_behaves_like 'a failed check'
      end

      context 'when caring for a dependent child under the age threshold' do
        let(:dependent_children_birth_dates) { [ cert_date - 10.years ] } # age 10 < 14

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when caring for both an under-threshold and an over-threshold child' do
        let(:dependent_children_birth_dates) { [ cert_date - 15.years, cert_date - 10.years ] } # 15yo + 10yo

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when the dependent child is at/over the age threshold throughout' do
        let(:dependent_children_birth_dates) { [ cert_date - 15.years ] } # turned 14 before the window

        it_behaves_like 'a failed check'
      end

      context 'when there is no caretaking data' do
        it_behaves_like 'a failed check'
      end
    end

    describe 'checking drug treatment' do
      let(:event_date) { [ cert_date - 2.months - 2.days ] }
      let(:member_data) { build(:certification_member_data, cert_date:, dates_in_drug_treatment: event_date) }

      it_behaves_like 'a mandatory exception', :drug_treatment

      context 'with invalid data' do
        let(:event_date) { [ 'not a date' ] }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking inmate' do
      let(:member_data) { build(:certification_member_data, cert_date:, dates_incarcerated:) }

      context 'when incarcerated during a certifiable month' do
        let(:dates_incarcerated) { [ cert_date - 2.months ] } # window covers that month directly

        it_behaves_like 'an applied external exception', 'inmate_excepted'
      end

      context 'when incarcerated before the window but the buffer reaches into a certifiable month' do
        # incarcerated cert_date - 5.months; +3-month buffer still covers certifiable months
        let(:dates_incarcerated) { [ cert_date - 5.months ] }

        it_behaves_like 'an applied external exception', 'inmate_excepted'
      end

      context 'when one incarceration window covers a certifiable month and another does not' do
        # cert_date - 8.months has expired (invalid); cert_date - 2.months is in-window (valid)
        let(:dates_incarcerated) { [ cert_date - 8.months, cert_date - 2.months ] }

        it_behaves_like 'an applied external exception', 'inmate_excepted'
      end

      context 'when the incarceration window (incl. buffer) ended before every certifiable month' do
        let(:dates_incarcerated) { [ cert_date - 8.months ] } # window ends ~cert_date - 5.months

        it_behaves_like 'a failed check'
      end

      context 'when there is no incarceration data' do
        let(:dates_incarcerated) { [] }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking inpatient-medical-care' do
      it_behaves_like 'an optional exception', :dates_receiving_inpatient_medical_care, :inpatient_medical_care
    end

    describe 'checking declared-emergency-county' do
      it_behaves_like 'an optional exception', :dates_in_declared_emergency_county, :declared_emergency_county
    end

    describe 'checking high-unemployment-county' do
      it_behaves_like 'an optional exception', :dates_in_high_unemployment_county, :high_unemployment_county
    end

    describe 'checking medical-travel' do
      it_behaves_like 'an optional exception', :dates_traveling_for_medical_care, :medical_travel
    end

    context 'when more than one exception check would apply' do
      let(:dates_receiving_inpatient_medical_care) { [ cert_date - 3.months ] }
      let(:dates_traveling_for_medical_care) { [ cert_date - 3.months ] }
      let(:member_data) { build(:certification_member_data, cert_date:, dates_traveling_for_medical_care:, dates_receiving_inpatient_medical_care:) }

      it 'records only the first applicable reason (stops at first success)' do
        service.determine(kase)
        determination = Determination.where(subject: certification, outcome: 'excepted').first
        expect(determination.reasons).to eq([ 'inpatient_medical_care_excepted' ])
      end
    end

    # Isolates the determine() plumbing from the concrete checks: whatever reason codes the checks
    # produce, determine records them and publishes DeterminedExcepted.
    context 'when checks are stubbed (positive-path wiring)' do
      before do
        allow(service).to receive(:applicable_exception_reason_codes).and_return([ 'inpatient_medical_care_excepted' ])
        allow(kase).to receive(:record_exception_determination)
      end

      it 'records the exception determination on the case' do
        service.determine(kase)
        expect(kase).to have_received(:record_exception_determination).with([ 'inpatient_medical_care_excepted' ], service)
      end

      it 'publishes DeterminedExcepted' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish)
          .with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
      end
    end
  end
end
