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
          described_class.perform_now(batch_upload.id)
          batch_upload.reload

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
          batch_upload.reload

          expect(batch_upload.results["successes"]).to be_present
          expect(batch_upload.results["successes"].first["member_id"]).to eq("M200")
        end

        it 'works regardless of feature flag' do
          with_batch_upload_v2_enabled do
            described_class.perform_now(batch_upload.id)
            batch_upload.reload
            expect(batch_upload).to be_completed
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
          batch_upload.reload

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

          batch_upload.reload
          expect(batch_upload).to be_failed
          expect(batch_upload.results["error"]).to eq("Test error")
        end
      end
    end

    context 'with cloud storage (v2 uploads)' do
      let(:batch_upload) do
        create(:certification_batch_upload, uploader: user, storage_key: "batch-uploads/test-uuid/test.csv")
      end
      let(:storage_adapter) { instance_double(Storage::S3Adapter) }
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M400,C-400,test4@example.com,Test,Four,2025-03-10,new_application
          M500,C-500,test5@example.com,Test,Five,2025-03-15,new_application
        CSV
      end

      before do
        # Set storage_adapter on Rails config for this test
        Rails.application.config.storage_adapter = storage_adapter
      end

      context 'when feature flag is ENABLED' do
        let(:csv_reader) { instance_double(CsvStreamReader) }

        before do
          allow(CsvStreamReader).to receive(:new).and_return(csv_reader)
        end

        it 'enqueues chunk jobs for streaming' do
          allow(csv_reader).to receive(:each_chunk).and_yield([
            { "member_id" => "M400", "case_number" => "C-400", "member_email" => "test4@example.com",
              "first_name" => "Test", "last_name" => "Four", "certification_date" => "2025-03-10",
              "certification_type" => "new_application" }
          ]).and_yield([
            { "member_id" => "M500", "case_number" => "C-500", "member_email" => "test5@example.com",
              "first_name" => "Test", "last_name" => "Five", "certification_date" => "2025-03-15",
              "certification_type" => "new_application" }
          ])

          with_batch_upload_v2_enabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.to have_enqueued_job(ProcessCertificationBatchChunkJob).exactly(2).times
          end
        end

        it 'updates num_rows' do
          allow(csv_reader).to receive(:each_chunk).and_yield(
            Array.new(1000) { {} }
          ).and_yield(
            Array.new(500) { {} }
          )

          with_batch_upload_v2_enabled do
            described_class.perform_now(batch_upload.id)
            batch_upload.reload
            expect(batch_upload.num_rows).to eq(1500)
          end
        end

        it 'marks as processing' do
          allow(csv_reader).to receive(:each_chunk).and_yield([ {} ])

          with_batch_upload_v2_enabled do
            described_class.perform_now(batch_upload.id)
            batch_upload.reload
            expect(batch_upload.status).to eq("processing")
          end
        end
      end

      context 'when feature flag is DISABLED' do
        before do
          allow(storage_adapter).to receive(:download_to_file) do |key:, file:|
            file.write(csv_content)
            file.rewind
          end
        end

        it 'falls back to sequential processing' do
          with_batch_upload_v2_disabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.not_to have_enqueued_job(ProcessCertificationBatchChunkJob)
          end
        end

        it 'still completes successfully' do
          with_batch_upload_v2_disabled do
            described_class.perform_now(batch_upload.id)
            batch_upload.reload

            expect(batch_upload).to be_completed
            expect(batch_upload.num_rows_succeeded).to eq(2)
          end
        end

        it 'creates certifications' do
          with_batch_upload_v2_disabled do
            expect {
              described_class.perform_now(batch_upload.id)
            }.to change(Certification, :count).by(2)
          end
        end
      end
    end

    context 'with invalid upload state' do
      let(:batch_upload) do
        batch = build(:certification_batch_upload, uploader: user)
        batch.file = nil
        batch.storage_key = nil
        batch.save(validate: false)
        batch
      end

      it 'marks batch as failed' do
        described_class.perform_now(batch_upload.id)
        batch_upload.reload

        expect(batch_upload).to be_failed
        expect(batch_upload.results["error"]).to include("missing both file attachment and storage key")
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
