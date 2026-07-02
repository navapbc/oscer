# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExclusionDeterminationService do
  let(:service) { described_class }
  let(:cert_date) { Date.new(2025, 7, 1) }
  let(:member_data) { build(:certification_member_data, date_of_birth: dob, cert_date: cert_date) }
  let(:rating_data) { nil }
  let(:veteran_disability_service) { instance_double(VeteranDisabilityService, get_disability_rating: rating_data) }

  before do
    allow(VeteranDisabilityService).to receive(:new).and_return(veteran_disability_service)
  end

  describe '#determine' do
    let(:certification) do
      create(
        :certification,
        member_data: member_data,
        # Pin the evaluation date to the same anchor as the DOBs (cert_date). The
        # factory default is a random future date, which flips age-boundary cases
        # (under-19, 64) by calendar day — a non-deterministic flake.
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date)
      )
    end
    let(:kase) { create(:certification_case, certification_id: certification.id) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    context 'when applicant is under 19 years old' do
      let(:dob) { cert_date - 18.years }

      it 'publishes DeterminedExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'logs approved event' do
        expect do
          service.determine(kase)
        end.to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.exclusion.approved').count }.by(1)
      end
    end

    context 'when applicant is 65 years old or older' do
      let(:dob) { cert_date - 65.years }

      it 'publishes DeterminedExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'logs denied event' do
        expect do
          service.determine(kase)
        end.to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.exclusion.denied').count }.by(1)
      end
    end

    context 'when date_of_birth is invalid format' do
      let(:dob) { "invalid-date-format" }

      it 'publishes DeterminedNotExcluded event' do
        allow(Rails.logger).to receive(:warn)
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

      it 'publishes DeterminedExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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
        build(:certification_member_data, race_ethnicity: "white", cert_date: cert_date)
      end

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

    context 'when member is pregnant' do
      let(:member_data) do
        build(:certification_member_data, pregnancy_status: true, cert_date: cert_date)
      end

      it 'publishes DeterminedExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

    context 'when member is not pregnant and does not qualify for other exemptions' do
      let(:member_data) do
        build(:certification_member_data, pregnancy_status: false, cert_date: cert_date)
      end

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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

    context 'when member is a veteran with 100% disability' do
      let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }
      let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

      it 'publishes DeterminedExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
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
    end

    context 'when member is a veteran but does not have 100% disability' do
      let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }
      let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 70 } } } }

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
      end

      it 'does not close the case' do
        service.determine(kase)
        kase.reload
        expect(kase.status).to eq("open")
      end
    end

    context 'when VA service returns nil (fail-open)' do
      let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }

      it 'publishes DeterminedNotExcluded event' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
      end
    end
  end
end
