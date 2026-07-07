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

  describe '#determine' do
    context 'when no exception check applies (no checks registered — current state)' do
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

    # The positive (excepted) path is wired but currently unreachable: no checks are registered, so
    # applicable_exception_reason_codes always returns []. This documents that when a check does
    # apply, the service records the determination and publishes DeterminedExcepted.
    context 'when an exception check applies (positive path wiring)' do
      before do
        allow(service).to receive(:applicable_exception_reason_codes).and_return([ 'some_reason' ])
        allow(kase).to receive(:record_exception_determination)
      end

      it 'records the exception determination on the case' do
        service.determine(kase)
        expect(kase).to have_received(:record_exception_determination).with([ 'some_reason' ], service)
      end

      it 'publishes DeterminedExcepted' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish)
          .with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
      end
    end
  end
end
