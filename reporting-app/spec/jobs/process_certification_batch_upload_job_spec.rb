# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessCertificationBatchUploadJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

  describe '#perform' do
    context 'with valid CSV' do
      before do
        allow(Strata::EventManager).to receive(:publish)

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
    end

    context 'with invalid CSV' do
      before do
        allow(Strata::EventManager).to receive(:publish)

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
      let (:certification_batch_upload_service) { instance_double(CertificationBatchUploadService) }

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

  describe 'job queuing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(batch_upload.id)
      }.to have_enqueued_job(described_class).with(batch_upload.id)
    end
  end
end
