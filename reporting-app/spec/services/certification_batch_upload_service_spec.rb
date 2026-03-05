# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationBatchUploadService do
  let(:service) { described_class.new }

  describe '#process_csv' do
    context 'with duplicate prevention' do
      let!(:existing_certification) do
        cert = create(:certification,
          member_id: "M123",
          case_number: "C-001"
        )
        # Manually set certification_requirements with date
        cert.update_column(:certification_requirements, { "certification_date" => "2025-01-15" })
        cert
      end

      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M123,C-001,john@example.com,John,Doe,2025-01-15,new_application
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'skips duplicate certifications' do
        allow(Strata::EventManager).to receive(:publish)

        # Ensure existing cert exists
        expect(Certification.count).to eq(1)
        expect(existing_certification).to be_persisted

        expect {
          service.process_csv(uploaded_file)
        }.not_to change(Certification, :count)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:message]).to include("Duplicate")
      end
    end

    context 'with missing headers' do
      required_headers = %w[member_id case_number member_email certification_date certification_type].freeze
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_type
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      required_headers.each do |missing_header|
        it "captures error when #{missing_header} header is missing" do
          headers = required_headers - [ missing_header ]
          csv_content = <<~CSV
            #{headers.join(",")}
            M123,C-001,john@example.com,John,Doe,2025-01-15,new_application
            M124,C-002,jane@example.com,Jane,Smith,2025-01-15,recertification
          CSV
          csv_file = Tempfile.new([ 'test', '.csv' ])
          csv_file.write(csv_content)
          csv_file.rewind
          uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')

          service.process_csv(uploaded_file)

          expect(service.errors.count).to eq(1)
          expect(service.errors.first[:message]).to include("Missing required columns: #{missing_header}")
        end
      end

      it 'mentions multiple missing headers' do
        csv_content = <<~CSV
          member_id,first_name,last_name
          M123,John,Doe
        CSV
        csv_file = Tempfile.new([ 'test', '.csv' ])
        csv_file.write(csv_content)
        csv_file.rewind
        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:message]).to include("Missing required columns: case_number, member_email, certification_date, certification_type")
      end
    end

    context 'with valid CSV file' do
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M123,C-001,john@example.com,John,Doe,2025-01-15,new_application
          M124,C-002,jane@example.com,Jane,Smith,2025-01-15,recertification
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'processes all rows successfully' do
        allow(Strata::EventManager).to receive(:publish)

        result = service.process_csv(uploaded_file)

        expect(result).to be true
        expect(service.total_processed).to eq(2)
        expect(service.successes.count).to eq(2)
        expect(service.errors.count).to eq(0)
      end

      it 'creates certifications in database' do
        allow(Strata::EventManager).to receive(:publish)

        expect {
          service.process_csv(uploaded_file)
        }.to change(Certification, :count).by(2)
      end

      it 'stores success details' do
        allow(Strata::EventManager).to receive(:publish)

        service.process_csv(uploaded_file)

        expect(service.successes.first).to include(
          row: 2,
          case_number: "C-001",
          member_id: "M123"
        )
      end
    end

    context 'with invalid CSV data' do
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M125,C-003,invalid@example.com,Test,User,2025-01-15,invalid_type
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'captures validation errors' do
        allow(Strata::EventManager).to receive(:publish)

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:row]).to eq(2)
        expect(service.errors.first[:message]).to be_present
      end

      it 'does not create invalid certifications' do
        allow(Strata::EventManager).to receive(:publish)

        expect {
          service.process_csv(uploaded_file)
        }.not_to change(Certification, :count)
      end
    end

    context 'with malformed CSV' do
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write("invalid,csv\n\"unclosed quote")
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'returns false and captures error' do
        result = service.process_csv(uploaded_file)

        expect(result).to be false
        expect(service.errors).not_to be_empty
        expect(service.errors.first[:message]).to include("Invalid CSV format")
      end
    end

    context 'with nil file' do
      it 'returns false' do
        result = service.process_csv(nil)
        expect(result).to be false
      end
    end

    context 'with mixed success and failure rows' do
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M125,C-004,valid@example.com,Valid,User,2025-01-15,new_application
          M999,C-005,invalid@example.com,Invalid,User,,new_application
          M126,C-006,another@example.com,Another,User,2025-01-15,recertification
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'processes valid rows and captures invalid rows' do
        allow(Strata::EventManager).to receive(:publish)

        service.process_csv(uploaded_file)

        expect(service.total_processed).to eq(3)
        expect(service.successes.count).to eq(2)
        expect(service.errors.count).to eq(1)
        expect(service.all_succeeded?).to be false
      end
    end

    context 'when delegating to processor' do
      let(:processor) { instance_double(UnifiedRecordProcessor) }
      let(:service) { described_class.new(processor: processor) }
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M123,C-001,john@example.com,John,Doe,2025-01-15,new_application
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }
      let(:mock_certification) { instance_double(Certification, id: 1, case_number: "C-001", member_id: "M123") }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'calls processor with string-keyed record hash' do
        expected_record = {
          "member_id" => "M123",
          "case_number" => "C-001",
          "member_email" => "john@example.com",
          "first_name" => "John",
          "last_name" => "Doe",
          "certification_date" => "2025-01-15",
          "certification_type" => "new_application"
        }

        allow(processor).to receive(:process).and_return(mock_certification)

        service.process_csv(uploaded_file)

        expect(processor).to have_received(:process)
          .with(expected_record, context: {})
      end

      it 'passes batch_upload context when batch_upload present' do
        batch_upload = create(:certification_batch_upload)
        service_with_batch = described_class.new(batch_upload: batch_upload, processor: processor)

        allow(processor).to receive(:process).and_return(mock_certification)

        service_with_batch.process_csv(uploaded_file)

        expect(processor).to have_received(:process)
          .with(anything, context: { batch_upload_id: batch_upload.id })
      end

      it 'passes empty context when no batch_upload' do
        allow(processor).to receive(:process).and_return(mock_certification)

        service.process_csv(uploaded_file)

        expect(processor).to have_received(:process)
          .with(anything, context: {})
      end
    end

    context 'when handling processor errors' do
      let(:processor) { instance_double(UnifiedRecordProcessor) }
      let(:service) { described_class.new(processor: processor) }
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M123,C-001,john@example.com,John,Doe,2025-01-15,new_application
        CSV
      end
      let(:csv_file) do
        file = Tempfile.new([ 'test', '.csv' ])
        file.write(csv_content)
        file.rewind
        file
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it 'maps ValidationError to service error format' do
        error = UnifiedRecordProcessor::ValidationError.new(
          BatchUploadErrors::Validation::MISSING_FIELDS,
          "Missing required fields: member_id"
        )
        allow(processor).to receive(:process).and_raise(error)

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:row]).to eq(2)
        expect(service.errors.first[:message]).to eq("Missing required fields: member_id")
        expect(service.results.first[:status]).to eq(:error)
      end

      it 'maps DuplicateError to service error format' do
        error = UnifiedRecordProcessor::DuplicateError.new(
          BatchUploadErrors::Duplicate::EXISTING_CERTIFICATION,
          "Duplicate certification found"
        )
        allow(processor).to receive(:process).and_raise(error)

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:row]).to eq(2)
        expect(service.errors.first[:message]).to eq("Duplicate certification found")
        expect(service.results.first[:status]).to eq(:duplicate)
      end

      it 'maps DatabaseError to service error format' do
        error = UnifiedRecordProcessor::DatabaseError.new(
          BatchUploadErrors::Database::SAVE_FAILED,
          "Database save failed"
        )
        allow(processor).to receive(:process).and_raise(error)

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:row]).to eq(2)
        expect(service.errors.first[:message]).to eq("Database save failed")
        expect(service.results.first[:status]).to eq(:error)
      end

      it 'handles generic StandardError' do
        error = StandardError.new("Unexpected error occurred")
        allow(processor).to receive(:process).and_raise(error)

        service.process_csv(uploaded_file)

        expect(service.errors.count).to eq(1)
        expect(service.errors.first[:row]).to eq(2)
        expect(service.errors.first[:message]).to eq("Unexpected error occurred")
        expect(service.results.first[:status]).to eq(:error)
      end
    end
  end

  describe '#all_succeeded?' do
    it 'returns true when all rows succeeded' do
      service.instance_variable_set(:@successes, [ { row: 1 } ])
      service.instance_variable_set(:@errors, [])

      expect(service.all_succeeded?).to be true
    end

    it 'returns false when there are errors' do
      service.instance_variable_set(:@successes, [ { row: 1 } ])
      service.instance_variable_set(:@errors, [ { row: 2 } ])

      expect(service.all_succeeded?).to be false
    end

    it 'returns false when nothing was processed' do
      expect(service.all_succeeded?).to be false
    end
  end
end
