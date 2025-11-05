# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationOrigin, type: :model do
  let(:certification) { create(:certification) }
  let(:user) { create(:user) }
  let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }

  describe 'validations' do
    it 'requires certification_id' do
      origin = described_class.new(source_type: CertificationOrigin::SOURCE_TYPE_MANUAL)
      expect(origin).not_to be_valid
      expect(origin.errors[:certification_id]).to be_present
    end

    it 'requires source_type' do
      origin = described_class.new(certification_id: certification.id)
      expect(origin).not_to be_valid
      expect(origin.errors[:source_type]).to be_present
    end

    it 'requires unique certification_id' do
      described_class.create!(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )

      duplicate = described_class.new(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_API
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:certification_id]).to include("has already been taken")
    end

    it 'validates source_type inclusion' do
      origin = described_class.new(
        certification_id: certification.id,
        source_type: "invalid_type"
      )

      expect(origin).not_to be_valid
      expect(origin.errors[:source_type]).to be_present
    end
  end

  describe 'scopes' do
    before do
      described_class.create!(
        certification_id: create(:certification).id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )
      described_class.create!(
        certification_id: create(:certification).id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )
    end

    it '.from_batch_upload returns batch upload origins' do
      results = described_class.from_batch_upload(batch_upload.id)

      expect(results.count).to eq(1)
      expect(results.first.source_type).to eq(CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD)
    end

    it '.manual_entries returns manual origins' do
      results = described_class.manual_entries

      expect(results.count).to eq(1)
      expect(results.first.source_type).to eq(CertificationOrigin::SOURCE_TYPE_MANUAL)
    end
  end

  describe 'type checking methods' do
    it '#batch_upload? returns true for batch upload type' do
      origin = described_class.new(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )

      expect(origin.batch_upload?).to be true
      expect(origin.manual?).to be false
      expect(origin.api?).to be false
    end

    it '#manual? returns true for manual type' do
      origin = described_class.new(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )

      expect(origin.manual?).to be true
      expect(origin.batch_upload?).to be false
    end
  end

  describe '#source' do
    it 'returns batch upload when source_type is batch_upload' do
      origin = described_class.create!(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
        source_id: batch_upload.id
      )

      expect(origin.source).to eq(batch_upload)
    end

    it 'returns nil when source_id is nil' do
      origin = described_class.create!(
        certification_id: certification.id,
        source_type: CertificationOrigin::SOURCE_TYPE_MANUAL
      )

      expect(origin.source).to be_nil
    end
  end
end
