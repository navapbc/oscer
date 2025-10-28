# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Certification, type: :model do
  describe 'after_create_commit callback' do
    it 'publishes CertificationCreated event with certification_id' do
      allow(Strata::EventManager).to receive(:publish)
      certification = build(:certification)

      certification.save!
      expect(Strata::EventManager).to have_received(:publish).with(
        'CertificationCreated',
        { certification_id: certification.id }
      )
    end
  end

  describe 'member name accessors' do
    context 'with structured name data' do
      let(:certification) do
        build(:certification, member_data: {
          "name" => {
            "first" => "Jane",
            "middle" => "Q",
            "last" => "Public",
            "suffix" => "Jr"
          }
        })
      end

      it 'returns full name from structured data' do
        expect(certification.member_name.full_name).to eq("Jane Q Public Jr")
      end
    end

    context 'with no member_data' do
      let(:certification) { build(:certification, member_data: nil) }

      it 'returns nil for full name' do
        expect(certification.member_name).to be_nil
      end
    end
  end

  describe '.exists_for?' do
    let!(:certification) do
      create(:certification,
        member_id: "M999",
        case_number: "C-999",
        certification_requirements: { "certification_date" => "2025-01-15" }
      )
    end

    it 'returns true when certification exists with matching compound key' do
      result = Certification.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: "2025-01-15"
      )

      expect(result).to be true
    end

    it 'returns false when member_id does not match' do
      result = Certification.exists_for?(
        member_id: "M000",
        case_number: "C-999",
        certification_date: "2025-01-15"
      )

      expect(result).to be false
    end

    it 'returns false when case_number does not match' do
      result = Certification.exists_for?(
        member_id: "M999",
        case_number: "C-000",
        certification_date: "2025-01-15"
      )

      expect(result).to be false
    end

    it 'returns false when certification_date does not match' do
      result = Certification.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: "2025-01-20"
      )

      expect(result).to be false
    end

    it 'handles Date objects' do
      result = Certification.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: Date.parse("2025-01-15")
      )

      expect(result).to be true
    end
  end

  describe '.from_batch_upload' do
    let(:user) { create(:user) }
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }
    let!(:batch_cert) { create(:certification, member_id: "M888", case_number: "C-888") }
    let!(:manual_cert) { create(:certification, member_id: "M889", case_number: "C-889") }

    before do
      CertificationOrigin.create!(
        certification_id: batch_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      CertificationOrigin.create!(
        certification_id: manual_cert.id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )
    end

    it 'returns only certifications from specified batch upload' do
      results = Certification.from_batch_upload(batch_upload.id)

      expect(results).to include(batch_cert)
      expect(results).not_to include(manual_cert)
    end
  end

  describe '#origin' do
    let(:certification) { create(:certification) }

    it 'returns nil when no origin exists' do
      expect(certification.origin).to be_nil
    end

    it 'returns origin when it exists' do
      origin = CertificationOrigin.create!(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )

      expect(certification.origin).to eq(origin)
    end
  end
end
