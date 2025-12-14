# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MemberStatusService do
  let(:service) { described_class }
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  describe '#determine' do
    context 'with Certification input' do
      it 'accepts a Certification object' do
        expect { service.determine(certification) }.not_to raise_error
      end

      it 'returns a MemberStatus instance' do
        result = service.determine(certification)
        expect(result).to be_a(MemberStatus)
      end
    end

    context 'with CertificationCase input' do
      it 'accepts a CertificationCase object' do
        expect { service.determine(certification_case) }.not_to raise_error
      end

      it 'returns a MemberStatus instance' do
        result = service.determine(certification_case)
        expect(result).to be_a(MemberStatus)
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for invalid record type' do
        expect { service.determine("invalid") }.to raise_error(ArgumentError)
      end

      it 'includes class name in error message' do
        expect { service.determine("invalid") }.to raise_error(/String/)
      end
    end

    context 'when Determination exists with outcome "exempt"' do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "automated",
               reasons: [ "age_over_65_exempt", "pregnancy_exempt" ])
      end

      it 'returns status "exempt"' do
        result = service.determine(certification)
        expect(result.status).to eq("exempt")
      end

      it 'returns the determination_method' do
        result = service.determine(certification)
        expect(result.determination_method).to eq("automated")
      end

      it 'returns all reason_codes' do
        result = service.determine(certification)
        expect(result.reason_codes).to eq([ "age_over_65_exempt", "pregnancy_exempt" ])
      end
    end

    context 'when multiple Determinations exist' do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "automated",
               reasons: [ "age_under_19_exempt" ],
               created_at: 1.day.ago)
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "manual",
               reasons: [ "age_over_65_exempt" ],
               created_at: Time.current)
      end

      it 'uses the most recent determination by created_at' do
        result = service.determine(certification)
        expect(result.status).to eq("compliant")
        expect(result.determination_method).to eq("manual")
        expect(result.reason_codes).to eq([ "age_over_65_exempt" ])
      end
    end

    context 'when no Determination exists' do
      context 'when no application forms are submitted' do
        it 'returns status "awaiting_report"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("awaiting_report")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to be_nil
        end

        it 'returns empty reason_codes' do
          result = service.determine(certification_case)
          expect(result.reason_codes).to be_empty
        end
      end

      context 'when business process is in review_activity_report step' do
        before do
          certification_case.update(business_process_current_step: CertificationBusinessProcess::REVIEW_ACTIVITY_REPORT_STEP)
        end

        it 'returns status "pending_review"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("pending_review")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to be_nil
        end
      end

      context 'when activity report is approved and business process is in end step' do
        before do
          certification_case.update(
            activity_report_approval_status: "approved",
            business_process_current_step: CertificationBusinessProcess::END_STEP
          )

          create(:determination,
            subject: certification,
            outcome: "compliant",
            decision_method: "manual",
            reasons: [ "hours_reported_compliant" ])
        end

        it 'returns status "compliant"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("compliant")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to eq("manual")
        end

        it 'returns all reason_codes' do
          result = service.determine(certification_case)
          expect(result.reason_codes).to eq([ "hours_reported_compliant" ])
        end

        it 'returns all human_readable_reason_codes' do
          result = service.determine(certification_case)
          expect(result.human_readable_reason_codes).to eq([ "Hours reported compliant" ])
        end
      end

      context 'when there is no approval and business process is in end step' do
        before do
          certification_case.update(
            business_process_current_step: CertificationBusinessProcess::END_STEP
          )
        end

        it 'returns status "not_compliant"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("not_compliant")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to be_nil
        end
      end

      context 'when exemption request is approved' do
        before do
          certification_case.update(
            exemption_request_approval_status: "approved",
            business_process_current_step: CertificationBusinessProcess::END_STEP
          )
          create(:determination,
            subject: certification,
            outcome: "exempt",
            decision_method: "manual",
            reasons: [ "exemption_request_compliant" ])
        end

        it 'returns status "exempt"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("exempt")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to eq("manual")
        end

        it 'returns all reason_codes' do
          result = service.determine(certification_case)
          expect(result.reason_codes).to eq([ "exemption_request_compliant" ])
        end

        it 'returns all human_readable_reason_codes' do
          result = service.determine(certification_case)
          expect(result.human_readable_reason_codes).to eq([ "Exemption request compliant" ])
        end
      end
    end

    context 'when CertificationCase is nil' do
      before do
        allow(CertificationCase).to receive(:find_by).and_return(nil)
      end

      it 'returns status "awaiting_report"' do
        result = service.determine(certification)
        expect(result.status).to eq("awaiting_report")
      end
    end
  end

  describe '#determine_many' do
    context 'with empty array' do
      it 'returns empty hash' do
        result = service.determine_many([])
        expect(result).to eq({})
      end
    end

    context 'with single Certification' do
      it 'returns hash with single result keyed by [class_name, id]' do
        result = service.determine_many([ certification ])
        key = [ "Certification", certification.id ]
        expect(result).to have_key(key)
        expect(result[key]).to be_a(MemberStatus)
      end
    end

    context 'with single CertificationCase' do
      it 'returns hash with single result keyed by [class_name, id]' do
        result = service.determine_many([ certification_case ])
        key = [ "CertificationCase", certification_case.id ]
        expect(result).to have_key(key)
        expect(result[key]).to be_a(MemberStatus)
      end
    end

    context 'with mixed Certification and CertificationCase inputs' do
      let(:cert2) { create(:certification) }
      let(:case2) { create(:certification_case, certification_id: cert2.id) }

      it 'returns results for all records' do
        result = service.determine_many([ certification, certification_case, cert2, case2 ])
        expect(result.size).to eq(4)
        expect(result).to have_key([ "Certification", certification.id ])
        expect(result).to have_key([ "CertificationCase", certification_case.id ])
        expect(result).to have_key([ "Certification", cert2.id ])
        expect(result).to have_key([ "CertificationCase", case2.id ])
      end
    end

    context 'with invalid input types' do
      it 'raises ArgumentError for mixed valid/invalid records' do
        expect { service.determine_many([ certification, "invalid" ]) }.to raise_error(ArgumentError)
      end

      it 'includes class name in error message' do
        expect { service.determine_many([ certification, "invalid" ]) }.to raise_error(/String/)
      end
    end

    context 'when Determinations exist' do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "automated",
               reasons: [ "age_over_65_exempt" ])
        create(:determination,
               subject: create(:certification),
               outcome: "compliant",
               decision_method: "manual",
               reasons: [ "hours_reported_compliant" ])
      end

      it 'returns correct statuses for records with determinations' do
        certs = Certification.all
        result = service.determine_many(certs)

        # Fetch determinations separately to avoid lazy loading issues
        exempt_dets = Determination.where(outcome: "exempt")
        compliant_dets = Determination.where(outcome: "compliant")

        first_cert_id = exempt_dets.first.subject_id
        second_cert_id = compliant_dets.first.subject_id

        expect(result[[ "Certification", first_cert_id ]].status).to eq("exempt")
        expect(result[[ "Certification", second_cert_id ]].status).to eq("compliant")
      end

      it 'uses the most recent determination when multiple exist' do
        cert = certification
        create(:determination,
               subject: cert,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "pregnancy_exempt" ],
               created_at: 1.hour.ago)
        create(:determination,
               subject: cert,
               outcome: "compliant",
               decision_method: "manual",
               reasons: [ "hours_reported_compliant" ],
               created_at: Time.current)

        result = service.determine_many([ cert ])
        expect(result[[ "Certification", cert.id ]].determination_method).to eq("manual")
        expect(result[[ "Certification", cert.id ]].reason_codes).to eq([ "hours_reported_compliant" ])
      end

      it 'includes human_readable_reason_codes' do
        result = service.determine_many([ certification ])
        status = result[[ "Certification", certification.id ]]
        expect(status.human_readable_reason_codes).to eq([ "Age over 65" ])
      end
    end

    context 'when no Determinations exist' do
      it 'returns awaiting_report status for unreviewed cases' do
        result = service.determine_many([ certification_case ])
        expect(result[[ "CertificationCase", certification_case.id ]].status).to eq("awaiting_report")
      end

      it 'returns pending_review status when in review step' do
        certification_case.update(business_process_current_step: CertificationBusinessProcess::REVIEW_ACTIVITY_REPORT_STEP)
        result = service.determine_many([ certification_case ])
        expect(result[[ "CertificationCase", certification_case.id ]].status).to eq("pending_review")
      end

      it 'returns not_compliant status when in end step without approval' do
        certification_case.update(business_process_current_step: CertificationBusinessProcess::END_STEP)
        result = service.determine_many([ certification_case ])
        expect(result[[ "CertificationCase", certification_case.id ]].status).to eq("not_compliant")
      end
    end

    context 'with large batch of records' do
      let(:certs) { create_list(:certification, 50) }
      let(:cases_with_det) do
        certs.first(25).map { |cert| create(:certification_case, certification_id: cert.id) }
      end
      let(:cases_without_det) do
        certs.last(25).map { |cert| create(:certification_case, certification_id: cert.id) }
      end

      before do
        # Create determinations for first 25 certs only
        certs.first(25).each do |cert|
          create(:determination,
                 subject: cert,
                 outcome: "compliant",
                 decision_method: "automated",
                 reasons: [ "hours_reported_compliant" ])
        end
      end

      it 'computes status for all records' do
        mixed = (cases_with_det + cases_without_det).shuffle
        result = service.determine_many(mixed)
        expect(result.size).to eq(50)
      end

      it 'returns correct statuses for records with and without determinations' do
        mixed = cases_with_det + cases_without_det
        result = service.determine_many(mixed)

        # Cases with determinations should show compliant status
        cases_with_det.each do |case_record|
          status = result[[ "CertificationCase", case_record.id ]]
          expect(status).to be_present
          expect(status.status).to eq("compliant")
        end

        # Cases without determinations should show awaiting_report status
        cases_without_det.each do |case_record|
          status = result[[ "CertificationCase", case_record.id ]]
          expect(status).to be_present
          expect(status.status).to eq("awaiting_report")
        end
      end
    end
  end
end
