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
