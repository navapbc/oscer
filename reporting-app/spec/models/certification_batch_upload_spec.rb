# frozen_string_literal: true

require 'rails_helper'
require 'support/query_count_matchers'

RSpec.describe CertificationBatchUpload, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'requires filename' do
      batch_upload = described_class.new(uploader: user)
      expect(batch_upload).not_to be_valid
      expect(batch_upload.errors[:filename]).to be_present
    end

    it 'requires file on create' do
      batch_upload = described_class.new(filename: "test.csv", uploader: user)
      expect(batch_upload).not_to be_valid
      expect(batch_upload.errors[:file]).to be_present
    end
  end

  describe 'status enum' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

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
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

    it 'marks as processing and resets progress' do
      batch_upload.start_processing!

      expect(batch_upload).to be_processing
      expect(batch_upload.num_rows_processed).to eq(0)
    end
  end

  describe '#complete_processing!' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :processing) }

    it 'marks as completed with results' do
      results = { successes: [ { row: 1 } ], errors: [] }

      batch_upload.complete_processing!(
        num_rows_succeeded: 1,
        num_rows_errored: 0,
        results: results
      )

      expect(batch_upload).to be_completed
      expect(batch_upload.num_rows_succeeded).to eq(1)
      expect(batch_upload.num_rows_errored).to eq(0)
      expect(batch_upload.results).to eq(results.deep_stringify_keys)
      expect(batch_upload.processed_at).to be_present
    end
  end

  describe '#fail_processing!' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :processing) }

    it 'marks as failed with error message' do
      batch_upload.fail_processing!(error_message: "Test error")

      expect(batch_upload).to be_failed
      expect(batch_upload.results["error"]).to eq("Test error")
      expect(batch_upload.processed_at).to be_present
    end
  end

  describe '#processable?' do
    it 'returns true when pending' do
      batch_upload = create(:certification_batch_upload, uploader: user, status: :pending)
      expect(batch_upload.processable?).to be true
    end

    it 'returns false when processing' do
      batch_upload = create(:certification_batch_upload, uploader: user, status: :processing)
      expect(batch_upload.processable?).to be false
    end

    it 'returns false when completed' do
      batch_upload = create(:certification_batch_upload, uploader: user, status: :completed)
      expect(batch_upload.processable?).to be false
    end
  end

  describe '#certifications' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }
    let(:cert_first) { create(:certification, member_id: "M777", case_number: "C-777") }
    let(:cert_second) { create(:certification, member_id: "M778", case_number: "C-778") }

    before do
      CertificationOrigin.create!(
        certification_id: cert_first.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: cert_second.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
    end

    it 'returns certifications created from this batch' do
      results = batch_upload.certifications

      expect(results).to include(cert_first, cert_second)
      expect(results.count).to eq(2)
    end
  end

  describe '#certifications_count' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

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
