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

  shared_examples 'a disabled external exception' do |exception_id|
    before do
      # Default to the real config, then disable only the exception under test, so the checks that
      # run before it (up to the first success) still consult real enablement.
      allow(ExternalException).to receive(:enabled?).and_call_original
      allow(ExternalException).to receive(:enabled?).with(exception_id).and_return(false)
    end

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

  describe '#determine' do
    context 'when no exception check applies (member data carries no exception signals)' do
      it 'publishes DeterminedNotExcepted' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish)
          .with('DeterminedNotExcepted', { case_id: kase.id, certification_id: kase.certification_id })
      end

      it 'does not close the case' do
        service.determine(kase)
        expect(kase.reload.status).to eq('open')
      end

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

    context 'when the inpatient-medical-care check applies' do
      let(:certification) do
        create(:certification, member_data: build(:certification_member_data, receiving_inpatient_medical_care: true))
      end

      it_behaves_like 'an applied external exception', 'inpatient_medical_care_excepted'
      it_behaves_like 'a disabled external exception', :inpatient_medical_care
    end

    context 'when the declared-emergency-county check applies' do
      let(:certification) do
        create(:certification, member_data: build(:certification_member_data, resides_in_declared_emergency_county: true))
      end

      it_behaves_like 'an applied external exception', 'declared_emergency_county_excepted'
      it_behaves_like 'a disabled external exception', :declared_emergency_county
    end

    context 'when the high-unemployment-county check applies' do
      let(:certification) do
        create(:certification, member_data: build(:certification_member_data, resides_in_high_unemployment_county: true))
      end

      it_behaves_like 'an applied external exception', 'high_unemployment_county_excepted'
      it_behaves_like 'a disabled external exception', :high_unemployment_county
    end

    context 'when the medical-travel check applies' do
      let(:certification) do
        create(:certification, member_data: build(:certification_member_data, traveling_for_medical_care: true))
      end

      it_behaves_like 'an applied external exception', 'medical_travel_excepted'
      it_behaves_like 'a disabled external exception', :medical_travel
    end

    context 'when more than one exception check would apply' do
      let(:certification) do
        create(:certification, member_data: build(
          :certification_member_data,
          receiving_inpatient_medical_care: true,
          resides_in_declared_emergency_county: true
        ))
      end

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
