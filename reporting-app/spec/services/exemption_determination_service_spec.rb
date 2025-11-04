# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionDeterminationService do
  let(:service) { described_class }
  let(:cert_date) { Date.new(2025, 7, 1) }
  let(:member_data) { build(:certification_member_data, date_of_birth: dob, cert_date: cert_date) }

  describe '#determine' do
    let(:certification) { create(:certification, member_data: member_data) }
    let(:kase) { create(:certification_case, certification_id: certification.id) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    context 'when applicant is under 19 years old' do
      let(:dob) { cert_date - 18.years }

      it 'publishes DeterminedExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExempt', { case_id: kase.id })
      end

      it 'closes the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("closed")
      end

      it 'sets exemption_request_approval_status to approved' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to eq("approved")
      end

      it 'sets exemption_request_approval_status_updated_at' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status_updated_at).to be_present
      end
    end

    context 'when applicant is 65 years old or older' do
      let(:dob) { cert_date - 65.years }

      it 'publishes DeterminedExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExempt', { case_id: kase.id })
      end

      it 'closes the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("closed")
      end

      it 'sets exemption_request_approval_status to approved' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to eq("approved")
      end

      it 'sets exemption_request_approval_status_updated_at' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status_updated_at).to be_present
      end
    end

    context 'when applicant is 19 years old' do
      let(:dob) { cert_date - 19.years }

      it 'publishes DeterminedNotExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExempt', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end

    context 'when applicant is 64 years old' do
      let(:dob) { cert_date - 64.years }

      it 'publishes DeterminedNotExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExempt', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end

    context 'when member_data has no date_of_birth' do
      let(:dob) { nil }

      it 'publishes DeterminedNotExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExempt', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end

    context 'when date_of_birth is invalid format' do
      let(:dob) { "invalid-date-format" }

      it 'publishes DeterminedNotExempt event' do
        allow(Rails.logger).to receive(:warn)
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExempt', { case_id: kase.id })
      end

      it 'does not close the case' do
        allow(Rails.logger).to receive(:warn)
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end
    end

    context 'when member is American Indian or Alaska Native' do
      let(:member_data) do
        build(:certification_member_data, race_ethnicity: "american_indian_or_alaska_native", cert_date: cert_date)
      end

      it 'publishes DeterminedExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExempt', { case_id: kase.id })
      end

      it 'closes the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("closed")
      end

      it 'sets exemption_request_approval_status to approved' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to eq("approved")
      end

      it 'sets exemption_request_approval_status_updated_at' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status_updated_at).to be_present
      end
    end

    context 'when member is not American Indian or Alaska Native' do
      let(:member_data) do
        build(:certification_member_data, race_ethnicity: "White", cert_date: cert_date)
      end

      it 'publishes DeterminedNotExempt event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExempt', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end
  end
end
