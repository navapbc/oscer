# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MemberStatusService do
  let(:service) { described_class }
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

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
end
