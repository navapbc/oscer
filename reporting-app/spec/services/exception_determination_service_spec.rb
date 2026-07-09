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
    let(:event_date) { [ cert_date - 3.months ] }
    let(:member_data) { build(:certification_member_data, cert_date:, attribute => event_date) }

    context 'when event in month that can be certified' do
      let(:months_that_can_be_certified) { (0..3).map { |i| cert_date - i.month } }

      it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
      it_behaves_like 'a disabled optional exception', exception_id
    end

    context 'when event not in month that can be certified' do
      let(:months_that_can_be_certified) { (0..2).map { |i| cert_date - i.month } }

      it_behaves_like 'a failed check'
    end
  end

  shared_examples 'a mandatory exception' do |exception_id|
    context 'when event in month that can be certified' do
      let(:months_that_can_be_certified) { (0..3).map { |i| cert_date - i.month } }

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
    let(:months_that_can_be_certified) { [] }
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
      let(:event_date) { [ cert_date - 3.months ] }
      let(:member_data) { build(:certification_member_data, cert_date:, participating_in_other_program: event_date) }

      it_behaves_like 'a mandatory exception', :other_program
    end

    describe 'checking inpatient-medical-care' do
      it_behaves_like 'an optional exception', :receiving_inpatient_medical_care, :inpatient_medical_care
    end

    describe 'checking declared-emergency-county' do
      it_behaves_like 'an optional exception', :resides_in_declared_emergency_county, :declared_emergency_county
    end

    describe 'checking high-unemployment-county' do
      it_behaves_like 'an optional exception', :resides_in_high_unemployment_county, :high_unemployment_county
    end

    describe 'checking medical-travel' do
      it_behaves_like 'an optional exception', :traveling_for_medical_care, :medical_travel
    end

    context 'when more than one exception check would apply' do
      let(:receiving_inpatient_medical_care) { [ cert_date - 3.months ] }
      let(:traveling_for_medical_care) { [ cert_date - 3.months ] }
      let(:member_data) { build(:certification_member_data, cert_date:, traveling_for_medical_care:, receiving_inpatient_medical_care:) }
      let(:months_that_can_be_certified) { (0..3).map { |i| cert_date - i.month } }

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
