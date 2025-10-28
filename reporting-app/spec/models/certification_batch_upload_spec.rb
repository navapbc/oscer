# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationBatchUpload, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'requires filename' do
      batch_upload = CertificationBatchUpload.new(uploaded_by: user)
      expect(batch_upload).not_to be_valid
      expect(batch_upload.errors[:filename]).to be_present
    end

    it 'requires file on create' do
      batch_upload = CertificationBatchUpload.new(filename: "test.csv", uploaded_by: user)
      expect(batch_upload).not_to be_valid
      expect(batch_upload.errors[:file]).to be_present
    end
  end

  describe 'status enum' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }

    it 'defaults to pending' do
      expect(batch_upload.status).to eq("pending")
      expect(batch_upload).to be_pending
    end

    it 'can transition to processing' do
      batch_upload.processing!
      expect(batch_upload).to be_processing
    end

    it 'can transition to completed' do
      batch_upload.completed!
      expect(batch_upload).to be_completed
    end

    it 'can transition to failed' do
      batch_upload.failed!
      expect(batch_upload).to be_failed
    end
  end

  describe '#start_processing!' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }

    it 'marks as processing and resets progress' do
      batch_upload.start_processing!

      expect(batch_upload).to be_processing
      expect(batch_upload.processed_rows).to eq(0)
    end
  end

  describe '#complete_processing!' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user, status: :processing) }

    it 'marks as completed with results' do
      results = { successes: [ { row: 1 } ], errors: [] }

      batch_upload.complete_processing!(
        success_count: 1,
        error_count: 0,
        results: results
      )

      expect(batch_upload).to be_completed
      expect(batch_upload.success_count).to eq(1)
      expect(batch_upload.error_count).to eq(0)
      expect(batch_upload.results).to eq(results.deep_stringify_keys)
      expect(batch_upload.processed_at).to be_present
    end
  end

  describe '#fail_processing!' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user, status: :processing) }

    it 'marks as failed with error message' do
      batch_upload.fail_processing!(error_message: "Test error")

      expect(batch_upload).to be_failed
      expect(batch_upload.results["error"]).to eq("Test error")
      expect(batch_upload.processed_at).to be_present
    end
  end

  describe '#processable?' do
    it 'returns true when pending' do
      batch_upload = create(:certification_batch_upload, uploaded_by: user, status: :pending)
      expect(batch_upload.processable?).to be true
    end

    it 'returns false when processing' do
      batch_upload = create(:certification_batch_upload, uploaded_by: user, status: :processing)
      expect(batch_upload.processable?).to be false
    end

    it 'returns false when completed' do
      batch_upload = create(:certification_batch_upload, uploaded_by: user, status: :completed)
      expect(batch_upload.processable?).to be false
    end
  end

  describe '#certifications' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }
    let!(:cert1) { create(:certification, member_id: "M777", case_number: "C-777") }
    let!(:cert2) { create(:certification, member_id: "M778", case_number: "C-778") }

    before do
      CertificationOrigin.create!(
        certification_id: cert1.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: cert2.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
    end

    it 'returns certifications created from this batch' do
      results = batch_upload.certifications

      expect(results).to include(cert1, cert2)
      expect(results.count).to eq(2)
    end
  end

  describe '#certifications_count' do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }

    it 'returns 0 when no certifications created' do
      expect(batch_upload.certifications_count).to eq(0)
    end

    it 'returns count of certifications from this batch' do
      2.times do |i|
        cert = create(:certification, member_id: "M#{800+i}", case_number: "C-#{800+i}")
        CertificationOrigin.create!(
          certification_id: cert.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: batch_upload.id
        )
      end

      expect(batch_upload.certifications_count).to eq(2)
    end
  end
end
