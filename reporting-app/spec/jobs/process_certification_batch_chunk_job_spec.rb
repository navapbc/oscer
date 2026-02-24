# frozen_string_literal: true

require 'rails_helper'
require 'aws-sdk-s3'

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
  let(:headers) { %w[member_id case_number member_email first_name last_name certification_date certification_type] }
  let(:start_byte) { 0 }
  let(:end_byte) { 999 }
  let(:csv_reader) { instance_double(CsvStreamReader) }

  before do
    allow(Strata::EventManager).to receive(:publish)
    allow(CsvStreamReader).to receive(:new).and_return(csv_reader)
  end

  describe '#perform' do
    context 'with all valid records' do
      let(:records) { [ valid_record ] }

      before do
        allow(csv_reader).to receive(:read_chunk).and_return(records)
      end

      it 'processes records and updates batch' do
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)

        expect(batch_upload.num_rows_processed).to eq(1)
        expect(batch_upload.num_rows_succeeded).to eq(1)
        expect(batch_upload.num_rows_errored).to eq(0)
      end

      it 'creates certifications' do
        expect {
          described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        }.to change(Certification, :count).by(1)
      end

      it 'creates certification origins' do
        expect {
          described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        }.to change(CertificationOrigin, :count).by(1)

        origin = CertificationOrigin.last
        expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD)
        expect(origin.source_id).to eq(batch_upload.id)
      end

      it 'creates audit log entry' do
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)

        logs = CertificationBatchUploadAuditLog
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:chunk_number, :status, :succeeded_count, :failed_count)

        expect(logs).to eq([ [ 1, "completed", 1, 0 ] ])
      end

      it 'does not create error entries' do
        expect {
          described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        }.not_to change(CertificationBatchUploadError, :count)
      end
    end

    context 'with mixed valid and invalid records' do
      let(:records) { [ valid_record, invalid_record, duplicate_record ] }

      before do
        allow(csv_reader).to receive(:read_chunk).and_return(records)
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
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)

        expect(batch_upload.num_rows_processed).to eq(3)
        expect(batch_upload.num_rows_succeeded).to eq(1) # Only valid_record
        expect(batch_upload.num_rows_errored).to eq(2) # invalid + duplicate
      end

      it 'creates audit log with correct counts' do
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)

        logs = CertificationBatchUploadAuditLog
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:chunk_number, :status, :succeeded_count, :failed_count)

        expect(logs).to eq([ [ 1, "completed", 1, 2 ] ])
      end

      it 'stores error details for failed records' do
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)

        errors = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .order(:row_number)
          .pluck(:row_number, :error_code, :error_message)

        # Invalid record error (row 3) and duplicate record error (row 4)
        expect(errors).to match([
          [ 3, a_string_starting_with("VAL_"), a_string_including("Missing required fields") ],
          [ 4, BatchUploadErrors::Duplicate::EXISTING_CERTIFICATION, a_string_including("Duplicate certification") ]
        ])
      end

      it 'continues processing after validation errors' do
        # All three records should be attempted, not stopped at first error
        batch_id = batch_upload.id
        described_class.perform_now(batch_id, 1, headers, start_byte, end_byte)

        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
        expect(batch_upload.num_rows_processed).to eq(3)
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
        allow(csv_reader).to receive(:read_chunk)
          .and_return(chunk_1_records, chunk_2_records, chunk_3_records)

        # Process chunks 1 and 2
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        described_class.perform_now(batch_upload.id, 2, headers, start_byte, end_byte)
        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
        expect(batch_upload.status).to eq("processing")

        # Process final chunk
        described_class.perform_now(batch_upload.id, 3, headers, start_byte, end_byte)
        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
        expect(batch_upload.status).to eq("completed")
      end

      it 'handles concurrent chunk completion safely' do
        allow(csv_reader).to receive(:read_chunk)
          .and_return(chunk_1_records, chunk_2_records, chunk_3_records)

        # Process all 3 chunks concurrently to test race condition handling
        threads = [
          Thread.new { described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte) },
          Thread.new { described_class.perform_now(batch_upload.id, 2, headers, start_byte, end_byte) },
          Thread.new { described_class.perform_now(batch_upload.id, 3, headers, start_byte, end_byte) }
        ]
        threads.each(&:join)

        batch_id = batch_upload.id

        batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
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
        allow(csv_reader).to receive(:read_chunk).and_return(records)

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)

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
        allow(csv_reader).to receive(:read_chunk).and_return(records)

        described_class.perform_now(batch_upload.id, 2, headers, start_byte, end_byte)

        # Chunk 2, index 0 → row (1000 + 2)
        error_row_numbers = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:row_number)

        expect(error_row_numbers).to eq([ chunk_size + 2 ])
      end
    end

    context 'when S3 read fails' do
      it 'marks audit log as failed and re-raises' do
        allow(csv_reader).to receive(:read_chunk)
          .and_raise(Aws::S3::Errors::ServiceError.new(nil, "S3 unavailable"))
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        }.to raise_error(Aws::S3::Errors::ServiceError)

        audit_log = CertificationBatchUploadAuditLog
          .find_by(certification_batch_upload_id: batch_upload.id)
        expect(audit_log.status).to eq("failed")
      end

      it 'does not increment batch counters' do
        allow(csv_reader).to receive(:read_chunk)
          .and_raise(Aws::S3::Errors::ServiceError.new(nil, "S3 unavailable"))
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)
        }.to raise_error(Aws::S3::Errors::ServiceError)

        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.find(batch_id)
        expect(batch_upload.num_rows_processed).to eq(0)
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

    context 'when delegating to processor' do
      let(:processor) { instance_double(UnifiedRecordProcessor) }
      let(:records) { [ valid_record ] }
      let(:mock_certification) { instance_double(Certification, id: 1) }

      before do
        allow(csv_reader).to receive(:read_chunk).and_return(records)
      end

      it 'calls processor with record and context' do
        allow(processor).to receive(:process).and_return(mock_certification)

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte, processor: processor)

        expect(processor).to have_received(:process)
          .with(valid_record, context: { batch_upload_id: batch_upload.id })
      end

      it 'uses injected processor instead of creating new one' do
        allow(processor).to receive(:process).and_return(mock_certification)
        allow(UnifiedRecordProcessor).to receive(:new).and_call_original

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte, processor: processor)

        # Should use injected processor, not create a new one
        expect(UnifiedRecordProcessor).not_to have_received(:new)
        expect(processor).to have_received(:process)
      end
    end

    context 'when delegating to reader' do
      before do
        allow(csv_reader).to receive(:read_chunk).and_return([ valid_record ])
      end

      it 'calls read_chunk with correct arguments' do
        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte)

        expect(csv_reader).to have_received(:read_chunk).with(
          batch_upload.storage_key,
          headers: headers,
          start_byte: start_byte,
          end_byte: end_byte
        )
      end
    end

    context 'when batch upload is deleted' do
      it 'returns early without processing when batch not found' do
        non_existent_id = "00000000-0000-0000-0000-000000000000"

        expect {
          described_class.perform_now(non_existent_id, 1, headers, start_byte, end_byte)
        }.not_to change(Certification, :count)

        # Should not create audit logs or errors
        expect(CertificationBatchUploadAuditLog.count).to eq(0)
        expect(CertificationBatchUploadError.count).to eq(0)
      end
    end

    context 'with unexpected errors' do
      let(:processor) { instance_double(UnifiedRecordProcessor) }
      let(:records) { [ valid_record ] }

      before do
        allow(csv_reader).to receive(:read_chunk).and_return(records)
      end

      it 'catches unexpected StandardError and logs with backtrace' do
        error = StandardError.new("Something went wrong")
        allow(processor).to receive(:process).and_raise(error)
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte, processor: processor)

        expect(Rails.logger).to have_received(:error).with(/Unexpected error processing row 2: StandardError - Something went wrong/)
        expect(Rails.logger).to have_received(:error).with(/Backtrace:/)
      end

      it 'stores error with UNK_001 code and exception class' do
        error = RuntimeError.new("Unexpected failure")
        allow(processor).to receive(:process).and_raise(error)
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte, processor: processor)

        errors = CertificationBatchUploadError
          .where(certification_batch_upload_id: batch_upload.id)
          .pluck(:error_code, :error_message)

        expect(errors).to eq([
          [ BatchUploadErrors::Unknown::UNEXPECTED, "Unexpected error: RuntimeError - Unexpected failure" ]
        ])
      end

      it 'increments error counter for unexpected errors' do
        error = StandardError.new("Something went wrong")
        allow(processor).to receive(:process).and_raise(error)
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(batch_upload.id, 1, headers, start_byte, end_byte, processor: processor)
        batch_id = batch_upload.id
        batch_upload = CertificationBatchUpload.find(batch_id)

        expect(batch_upload.num_rows_errored).to eq(1)
        expect(batch_upload.num_rows_succeeded).to eq(0)
      end
    end
  end

  describe 'job queuing' do
    it 'enqueues the job with correct parameters' do
      expect {
        described_class.perform_later(batch_upload.id, 1, headers, start_byte, end_byte)
      }.to have_enqueued_job(described_class).with(batch_upload.id, 1, headers, start_byte, end_byte)
    end
  end
end
