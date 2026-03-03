# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessCertificationBatchUploadJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    allow(Strata::EventManager).to receive(:publish)
  end

  describe '#perform' do
    context 'with Active Storage (legacy v1 path)' do
      let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

      context 'with valid CSV' do
        before do
          # Attach valid CSV content
          csv_content = <<~CSV
            member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
            M200,C-200,test@example.com,Test,User,2025-01-15,new_application
            M300,C-300,test2@example.com,Aurélie,Castañeda,2025-02-20,new_application
          CSV
          batch_upload.file.attach(
            io: StringIO.new(csv_content),
            filename: 'test.csv',
            content_type: 'text/csv'
          )
        end

        it 'processes the batch upload successfully' do
          batch_id = batch_upload.id
          described_class.perform_now(batch_id)
          batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)

          expect(batch_upload).to be_completed
          expect(batch_upload.num_rows_succeeded).to eq(2)
          expect(batch_upload.num_rows_errored).to eq(0)
        end

        it 'creates certifications' do
          expect {
            described_class.perform_now(batch_upload.id)
          }.to change(Certification, :count).from(0).to(2)
        end

        it 'stores results' do
          described_class.perform_now(batch_upload.id)
          batch_id = batch_upload.id
          batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)

          expect(batch_upload.results["successes"]).to be_present
          expect(batch_upload.results["successes"].first["member_id"]).to eq("M200")
        end
      end

      context 'with v2 feature flag enabled' do
        let(:csv_reader) { instance_double(CsvStreamReader) }

        before do
          # Attach valid CSV content
          csv_content = <<~CSV
            member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
            M200,C-200,test@example.com,Test,User,2025-01-15,new_application
            M300,C-300,test2@example.com,Aurélie,Castañeda,2025-02-20,new_application
          CSV
          batch_upload.file.attach(
            io: StringIO.new(csv_content),
            filename: 'test.csv',
            content_type: 'text/csv'
          )

          allow(CsvStreamReader).to receive(:new).and_return(csv_reader)
          # Mock each_chunk_with_offsets for single-pass behavior
          allow(csv_reader).to receive(:each_chunk_with_offsets)
            .and_yield(
              [
                { "member_id" => "M200", "case_number" => "C-200", "member_email" => "test@example.com",
                  "first_name" => "Test", "last_name" => "User", "certification_date" => "2025-01-15",
                  "certification_type" => "new_application" }
              ],
              %w[member_id case_number member_email first_name last_name certification_date certification_type],
              0,
              100
            ).and_yield(
              [
                { "member_id" => "M300", "case_number" => "C-300", "member_email" => "test2@example.com",
                  "first_name" => "Aurélie", "last_name" => "Castañeda", "certification_date" => "2025-02-20",
                  "certification_type" => "new_application" }
              ],
              %w[member_id case_number member_email first_name last_name certification_date certification_type],
              101,
              200
            )
        end

        it 'enqueues chunk jobs for parallel processing' do
          with_batch_upload_v2_enabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.to have_enqueued_job(ProcessCertificationBatchChunkJob).exactly(2).times

            # Verify the new argument format: (id, chunk_number, headers, start_byte, end_byte)
            enqueued = queue_adapter.enqueued_jobs.select do |j|
              j["job_class"] == "ProcessCertificationBatchChunkJob"
            end
            expected_headers = %w[
              member_id case_number member_email first_name last_name certification_date certification_type
            ]
            expect(enqueued[0]["arguments"]).to eq(
              [
                batch_upload.id,
                1,
                expected_headers,
                0,
                100
              ]
            )
            expect(enqueued[1]["arguments"]).to eq(
              [
                batch_upload.id,
                2,
                expected_headers,
                101,
                200
              ]
            )
          end
        end

        it 'updates num_rows before enqueueing jobs' do
          with_batch_upload_v2_enabled do
            described_class.perform_now(batch_upload.id)
            batch_id = batch_upload.id
            batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
            expect(batch_upload.num_rows).to eq(2)
          end
        end

        it 'marks batch as processing' do
          with_batch_upload_v2_enabled do
            described_class.perform_now(batch_upload.id)
            batch_id = batch_upload.id
            batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
            expect(batch_upload.status).to eq("processing")
          end
        end

        it 'marks batch as failed when streaming raises' do
          allow(csv_reader).to receive(:each_chunk_with_offsets)
            .and_raise(StandardError, "S3 connection lost")

          with_batch_upload_v2_enabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.to raise_error(StandardError, "S3 connection lost")

            batch_id = batch_upload.id
            batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
            expect(batch_upload).to be_failed
            expect(batch_upload.results["error"]).to eq("S3 connection lost")
          end
        end

        it 'handles empty CSV (headers but no data)' do
          allow(csv_reader).to receive(:each_chunk_with_offsets)  # No yields = no data rows

          with_batch_upload_v2_enabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.not_to have_enqueued_job(ProcessCertificationBatchChunkJob)

            batch_id = batch_upload.id
            batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
            expect(batch_upload.status).to eq("completed")
            expect(batch_upload.num_rows).to eq(0)
          end
        end
      end

      context 'with invalid CSV' do
        before do
          # Attach invalid CSV (missing required fields)
          csv_content = <<~CSV
            member_id,case_number,member_email
            ,C-201,invalid@example.com
          CSV
          batch_upload.file.attach(
            io: StringIO.new(csv_content),
            filename: 'test.csv',
            content_type: 'text/csv'
          )
        end

        it 'marks batch as failed' do
          described_class.perform_now(batch_upload.id)
          batch_id = batch_upload.id
          batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)

          expect(batch_upload).to be_failed
        end
      end

      context 'when processing fails' do
        let(:certification_batch_upload_service) { instance_double(CertificationBatchUploadService) }

        before do
          allow(CertificationBatchUploadService).to receive(:new).and_return(certification_batch_upload_service)
          allow(certification_batch_upload_service).to receive(:process_csv).and_raise(StandardError, "Test error")
        end

        it 'marks batch as failed' do
          expect {
            described_class.perform_now(batch_upload.id)
          }.to raise_error(StandardError)

          batch_id = batch_upload.id

          batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_id)
          expect(batch_upload).to be_failed
          expect(batch_upload.results["error"]).to eq("Test error")
        end
      end
    end
  end

  describe 'job queuing' do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

    it 'enqueues the job' do
      expect {
        described_class.perform_later(batch_upload.id)
      }.to have_enqueued_job(described_class).with(batch_upload.id)
    end
  end
end
