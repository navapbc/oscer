# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staff::CertificationBatchUploadsController do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET #results" do
    let(:batch_upload) { create(:certification_batch_upload) }
    let(:compliant_cert) { create(:certification) }
    let(:exempt_cert) { create(:certification) }
    let(:not_compliant_cert) { create(:certification) }
    let(:pending_review_cert) { create(:certification) }

    # Default status for pending_review_cert (can be overridden in specific contexts)
    let(:pending_review_cert_status) { MemberStatus::PENDING_REVIEW }

    before do
      # Create certification origins linking certifications to batch upload
      CertificationOrigin.create!(
        certification_id: compliant_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: exempt_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: not_compliant_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: pending_review_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )

      # Stub MemberStatusService to return different statuses
      allow(MemberStatusService).to receive(:determine).with(compliant_cert).and_return(
        MemberStatus.new(status: MemberStatus::COMPLIANT, determination_method: "automated", reason_codes: [])
      )
      allow(MemberStatusService).to receive(:determine).with(exempt_cert).and_return(
        MemberStatus.new(status: MemberStatus::EXEMPT, determination_method: "automated", reason_codes: [ "age_under_19_exempt" ])
      )
      allow(MemberStatusService).to receive(:determine).with(not_compliant_cert).and_return(
        MemberStatus.new(status: MemberStatus::NOT_COMPLIANT, determination_method: "automated", reason_codes: [])
      )
      allow(MemberStatusService).to receive(:determine).with(pending_review_cert).and_return(
        MemberStatus.new(status: pending_review_cert_status, determination_method: "manual", reason_codes: [])
      )
    end

    context "when accessing without filters" do
      it "loads certifications from the batch upload" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        certifications = controller.instance_variable_get(:@certifications)
        expect(certifications).to contain_exactly(compliant_cert, exempt_cert, not_compliant_cert, pending_review_cert)
      end

      it "calculates member statuses for all certifications" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        member_statuses = controller.instance_variable_get(:@member_statuses)
        expect(member_statuses).to be_present
        expect(member_statuses[compliant_cert.id].status).to eq(MemberStatus::COMPLIANT)
        expect(member_statuses[exempt_cert.id].status).to eq(MemberStatus::EXEMPT)
        expect(member_statuses[not_compliant_cert.id].status).to eq(MemberStatus::NOT_COMPLIANT)
        expect(member_statuses[pending_review_cert.id].status).to eq(MemberStatus::PENDING_REVIEW)
      end

      it "groups certifications by status" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        compliant = controller.instance_variable_get(:@compliant_certifications)
        exempt = controller.instance_variable_get(:@exempt_certifications)
        member_action = controller.instance_variable_get(:@member_action_required_certifications)
        pending_review = controller.instance_variable_get(:@pending_review_certifications)

        expect(compliant).to contain_exactly(compliant_cert)
        expect(exempt).to contain_exactly(exempt_cert)
        expect(member_action).to contain_exactly(not_compliant_cert)
        expect(pending_review).to contain_exactly(pending_review_cert)
      end

      it "shows all certifications by default" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        certifications_to_show = controller.instance_variable_get(:@certifications_to_show)
        expect(certifications_to_show).to contain_exactly(compliant_cert, exempt_cert, not_compliant_cert, pending_review_cert)
      end

      it "renders successfully" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        expect(response).to have_http_status(:success)
      end
    end

    context "when filtering by compliant" do
      it "shows only compliant certifications" do
        get :results, params: { id: batch_upload.id, filter: "compliant", locale: "en" }

        certifications_to_show = controller.instance_variable_get(:@certifications_to_show)
        expect(certifications_to_show).to contain_exactly(compliant_cert)
      end
    end

    context "when filtering by exempt" do
      it "shows only exempt certifications" do
        get :results, params: { id: batch_upload.id, filter: "exempt", locale: "en" }

        certifications_to_show = controller.instance_variable_get(:@certifications_to_show)
        expect(certifications_to_show).to contain_exactly(exempt_cert)
      end
    end

    context "when filtering by member_action_required" do
      # Override to use AWAITING_REPORT status for this test
      let(:pending_review_cert_status) { MemberStatus::AWAITING_REPORT }

      it "shows certifications requiring member action" do
        get :results, params: { id: batch_upload.id, filter: "member_action_required", locale: "en" }

        certifications_to_show = controller.instance_variable_get(:@certifications_to_show)
        expect(certifications_to_show).to contain_exactly(not_compliant_cert, pending_review_cert)
      end
    end

    context "when filtering by pending_review" do
      it "shows only pending review certifications" do
        get :results, params: { id: batch_upload.id, filter: "pending_review", locale: "en" }

        certifications_to_show = controller.instance_variable_get(:@certifications_to_show)
        expect(certifications_to_show).to contain_exactly(pending_review_cert)
      end
    end
  end
end
