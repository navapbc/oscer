# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionDeterminationService do
  let(:service) { described_class }

  describe '#determine!' do
    let(:certification) { create(:certification, :with_member_data_base) }
    let(:kase) { create(:certification_case, certification_id: certification.id) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      kase.update(certification_id: certification.id)
    end

    context 'when applicant is under 19 years old' do
      let(:dob) { Date.current - 18.years }
      let(:certification) do
        create(:certification, :with_member_data_base,
               member_data_base: { "name" => {}, "date_of_birth" => dob.iso8601 })
      end

      it 'publishes DeterminedExempt event' do
        service.determine!(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExempt', { case_id: kase.id })
      end

      it 'closes the case' do
        service.determine!(kase)
        kase.reload
        expect(kase.status).to eq("closed")
      end

      it 'sets exemption_request_approval_status to approved' do
        service.determine!(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to eq("approved")
      end

      it 'sets exemption_request_approval_status_updated_at' do
        service.determine!(kase)
        kase.reload
        expect(kase.exemption_request_approval_status_updated_at).to be_present
      end
    end

    context 'when applicant is 65 years old or older' do
      let(:dob) { Date.current - 65.years }
      let(:certification) do
        create(:certification, :with_member_data_base,
               member_data_base: { "name" => {}, "date_of_birth" => dob.iso8601 })
      end

      it 'publishes DeterminedExempt event' do
        service.determine!(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExempt', { case_id: kase.id })
      end

      it 'closes the case' do
        service.determine!(kase)
        kase.reload
        expect(kase.status).to eq("closed")
      end
    end

    context 'when applicant is 19 years old' do
      let(:dob) { Date.current - 19.years }
      let(:certification) do
        create(:certification, :with_member_data_base,
               member_data_base: { "name" => {}, "date_of_birth" => dob.iso8601 })
      end

      it 'publishes DeterminedRequirementsNotMet event' do
        service.determine!(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedRequirementsNotMet', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine!(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine!(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end

    context 'when applicant is 64 years old' do
      let(:dob) { Date.current - 64.years }
      let(:certification) do
        create(:certification, :with_member_data_base,
               member_data_base: { "name" => {}, "date_of_birth" => dob.iso8601 })
      end

      it 'publishes DeterminedRequirementsNotMet event' do
        service.determine!(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedRequirementsNotMet', { case_id: kase.id })
      end

      it 'does not close the case' do
        service.determine!(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end

      it 'does not set exemption_request_approval_status' do
        service.determine!(kase)
        kase.reload
        expect(kase.exemption_request_approval_status).to be_nil
      end
    end

    context 'when member_data has no date_of_birth' do
      let(:certification) do
        create(:certification, :with_member_data_base,
               member_data_base: { "name" => {} })
      end

      it 'publishes DeterminedRequirementsNotMet event' do
        service.determine!(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedRequirementsNotMet', { case_id: kase.id })
      end
    end
  end
end
