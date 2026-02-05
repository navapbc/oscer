# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessCertificationBatchChunkJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :processing, num_rows: 3) }
  let(:valid_record) do
    {
      "member_id" => "M600",
      "case_number" => "C-600",
      "member_email" => "test6@example.com",
      "first_name" => "Test",
      "last_name" => "Six",
      "certification_date" => "2025-04-10",
      "certification_type" => "new_application"
    }
  end
  let(:invalid_record) do
    {
      "member_id" => "M700",
      "case_number" => "C-700"
      # Missing required fields
    }
  end
  let(:duplicate_record) do
    {
      "member_id" => "M800",
      "case_number" => "C-800",
      "member_email" => "test8@example.com",
      "first_name" => "Test",
      "last_name" => "Eight",
      "certification_date" => "2025-04-12",
      "certification_type" => "new_application"
    }
  end

  before do
    allow(Strata::EventManager).to receive(:publish)
  end

  describe '#perform' do
    context 'with all valid records' do
      let(:records) { [ valid_record ] }

      it 'processes records and updates batch' do
        described_class.perform_now(batch_upload.id, 1, records)
        batch_upload.reload

        expect(batch_upload.num_rows_processed).to eq(1)
        expect(batch_upload.num_rows_succeeded).to eq(1)
        expect(batch_upload.num_rows_errored).to eq(0)
      end

      it 'creates certifications' do
        expect {
          described_class.perform_now(batch_upload.id, 1, records)
        }.to change(Certification, :count).by(1)
      end

      it 'creates certification origins' do
        expect {
          described_class.perform_now(batch_upload.id, 1, records)
        }.to change(CertificationOrigin, :count).by(1)

        origin = CertificationOrigin.last
        expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD)
        expect(origin.source_id).to eq(batch_upload.id)
      end

      it 'creates audit log entry' do
        described_class.perform_now(batch_upload.id, 1, records)

        logs = CertificationBatchUploadAuditLog
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:chunk_number, :status, :succeeded_count, :failed_count)

        expect(logs).to eq([ [ 1, "completed", 1, 0 ] ])
      end

      it 'does not create error entries' do
        expect {
          described_class.perform_now(batch_upload.id, 1, records)
        }.not_to change(CertificationBatchUploadError, :count)
      end
    end

    context 'with mixed valid and invalid records' do
      let(:records) { [ valid_record, invalid_record, duplicate_record ] }

      before do
        # Create existing certification for duplicate check
        create(:certification,
          member_id: duplicate_record["member_id"],
          case_number: duplicate_record["case_number"],
          certification_requirements: {
            certification_date: duplicate_record["certification_date"]
          }
        )
      end

      it 'processes all records and tracks results' do
        described_class.perform_now(batch_upload.id, 1, records)
        batch_upload.reload

        expect(batch_upload.num_rows_processed).to eq(3)
        expect(batch_upload.num_rows_succeeded).to eq(1) # Only valid_record
        expect(batch_upload.num_rows_errored).to eq(2) # invalid + duplicate
      end

      it 'creates audit log with correct counts' do
        described_class.perform_now(batch_upload.id, 1, records)

        logs = CertificationBatchUploadAuditLog
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:chunk_number, :status, :succeeded_count, :failed_count)

        expect(logs).to eq([ [ 1, "completed", 1, 2 ] ])
      end

      it 'stores error details for failed records' do
        described_class.perform_now(batch_upload.id, 1, records)

        errors = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .order(:row_number)
          .pluck(:row_number, :error_code, :error_message)

        # Invalid record error (row 3) and duplicate record error (row 4)
        expect(errors).to match([
          [ 3, a_string_starting_with("VAL_"), a_string_including("Missing required fields") ],
          [ 4, "DUP_001", a_string_including("Duplicate certification") ]
        ])
      end

      it 'continues processing after validation errors' do
        # All three records should be attempted, not stopped at first error
        described_class.perform_now(batch_upload.id, 1, records)

        expect(batch_upload.reload.num_rows_processed).to eq(3)
      end
    end

    context 'with multiple chunks completing' do
      let(:chunk_1_records) { [ valid_record ] }
      let(:chunk_2_record) do
        valid_record.merge(
          "member_id" => "M601",
          "case_number" => "C-601",
          "member_email" => "test601@example.com"
        )
      end
      let(:chunk_2_records) { [ chunk_2_record ] }
      let(:chunk_3_record) do
        valid_record.merge(
          "member_id" => "M602",
          "case_number" => "C-602",
          "member_email" => "test602@example.com"
        )
      end
      let(:chunk_3_records) { [ chunk_3_record ] }

      it 'marks batch as complete when all chunks finish' do
        # Process chunks 1 and 2
        described_class.perform_now(batch_upload.id, 1, chunk_1_records)
        described_class.perform_now(batch_upload.id, 2, chunk_2_records)
        batch_upload.reload
        expect(batch_upload.status).to eq("processing")

        # Process final chunk
        described_class.perform_now(batch_upload.id, 3, chunk_3_records)
        batch_upload.reload
        expect(batch_upload.status).to eq("completed")
      end

      it 'handles concurrent chunk completion safely' do
        # Process all 3 chunks concurrently to test race condition handling
        threads = [
          Thread.new { described_class.perform_now(batch_upload.id, 1, chunk_1_records) },
          Thread.new { described_class.perform_now(batch_upload.id, 2, chunk_2_records) },
          Thread.new { described_class.perform_now(batch_upload.id, 3, chunk_3_records) }
        ]
        threads.each(&:join)

        batch_upload.reload
        expect(batch_upload.status).to eq("completed")
        expect(batch_upload.num_rows_processed).to eq(3)
        expect(batch_upload.num_rows_succeeded).to eq(3)
        expect(batch_upload.num_rows_errored).to eq(0)

        # Verify all certifications were created
        expect(Certification.where(
          member_id: [ "M600", "M601", "M602" ]
        ).count).to eq(3)
      end
    end

    context 'with row number calculation' do
      it 'calculates correct row numbers for first chunk' do
        records = [ valid_record, invalid_record ]
        described_class.perform_now(batch_upload.id, 1, records)

        # Chunk 1, index 0 → row 2 (first data row after header)
        # Chunk 1, index 1 → row 3 (invalid record)
        error_row_numbers = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:row_number)

        expect(error_row_numbers).to eq([ 3 ])
      end

      it 'calculates correct row numbers for second chunk' do
        records = [ invalid_record ]
        chunk_size = CsvStreamReader::DEFAULT_CHUNK_SIZE

        described_class.perform_now(batch_upload.id, 2, records)

        # Chunk 2, index 0 → row (1000 + 2)
        error_row_numbers = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:row_number)

        expect(error_row_numbers).to eq([ chunk_size + 2 ])
      end
    end

    context 'with error handling configuration' do
      it 'is configured to retry on ActiveRecord::Deadlocked' do
        # Verify the retry_on configuration exists
        retry_callbacks = described_class.rescue_handlers.select do |handler|
          handler.first == "ActiveRecord::Deadlocked"
        end

        expect(retry_callbacks).not_to be_empty
      end
    end
  end

  describe 'job queuing' do
    it 'enqueues the job with correct parameters' do
      records = [ valid_record ]

      expect {
        described_class.perform_later(batch_upload.id, 1, records)
      }.to have_enqueued_job(described_class).with(batch_upload.id, 1, records)
    end
  end
end
