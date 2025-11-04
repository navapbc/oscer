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

    context 'when Determination exists with outcome "compliant"' do
      before do
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "age_under_19_exempt" ])
      end

      it 'returns status "compliant"' do
        result = service.determine(certification)
        expect(result.status).to eq("compliant")
      end

      it 'returns the determination_method' do
        result = service.determine(certification)
        expect(result.determination_method).to eq("automated")
      end

      it 'returns the reason_codes array' do
        result = service.determine(certification)
        expect(result.reason_codes).to eq([ "age_under_19_exempt" ])
      end
    end

    context 'when Determination exists with outcome "exempt"' do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "manual",
               reasons: [ "age_over_65_exempt", "pregnancy_exempt" ])
      end

      it 'returns status "exempt"' do
        result = service.determine(certification)
        expect(result.status).to eq("exempt")
      end

      it 'returns the determination_method' do
        result = service.determine(certification)
        expect(result.determination_method).to eq("manual")
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
      context 'and no application forms are submitted' do
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

      context 'and activity report is submitted but not approved' do
        before do
          create(:activity_report_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
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

      context 'and exemption request is submitted but not approved' do
        before do
          create(:exemption_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
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

      context 'and activity report is approved' do
        before do
          create(:activity_report_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
          certification_case.update(activity_report_approval_status: "approved")
        end

        it 'returns status "compliant"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("compliant")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to be_nil
        end
      end

      context 'and activity report is denied' do
        before do
          create(:activity_report_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
          certification_case.update(activity_report_approval_status: "denied")
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

      context 'and exemption request is approved' do
        before do
          create(:exemption_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
          certification_case.update(exemption_request_approval_status: "approved")
        end

        it 'returns status "exempt"' do
          result = service.determine(certification_case)
          expect(result.status).to eq("exempt")
        end

        it 'returns nil determination_method' do
          result = service.determine(certification_case)
          expect(result.determination_method).to be_nil
        end
      end

      context 'and exemption request is denied' do
        before do
          create(:exemption_application_form,
                 certification_case_id: certification_case.id,
                 status: "submitted")
          certification_case.update(exemption_request_approval_status: "denied")
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

    context 'when Certification is nil' do
      let(:orphan_case) { create(:certification_case, certification_id: nil) }

      it 'returns status "awaiting_report"' do
        result = service.determine(orphan_case)
        expect(result.status).to eq("awaiting_report")
      end

      it 'handles nil determination gracefully' do
        expect { service.determine(orphan_case) }.not_to raise_error
      end
    end

    context 'Determination takes precedence over CertificationCase state' do
      before do
        create(:activity_report_application_form,
               certification_case_id: certification_case.id,
               status: "submitted")
        certification_case.update(activity_report_approval_status: "pending")

        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "automated",
               reasons: [ "age_under_19_exempt" ])
      end

      it 'returns status from Determination, not from CertificationCase' do
        result = service.determine(certification_case)
        expect(result.status).to eq("exempt")
        expect(result.determination_method).to eq("automated")
      end
    end

    context 'return value validation' do
      let(:result) { service.determine(certification_case) }

      it 'has a status attribute' do
        expect(result).to respond_to(:status)
      end

      it 'has a determination_method attribute' do
        expect(result).to respond_to(:determination_method)
      end

      it 'has a reason_codes attribute' do
        expect(result).to respond_to(:reason_codes)
      end

      it 'status value is within allowed values' do
        expect(%w[compliant exempt not_compliant pending_review awaiting_report]).to include(result.status)
      end
    end
  end
end
