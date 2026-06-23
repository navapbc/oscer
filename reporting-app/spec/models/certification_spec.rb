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
    let(:certification) do
      create(:certification,
        member_id: "M999",
        case_number: "C-999",
        certification_requirements: { "certification_date" => "2025-01-15" }
      )
    end

    before do
      certification # ensure creation
    end

    it 'returns true when certification exists with matching compound key' do
      result = described_class.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: "2025-01-15"
      )

      expect(result).to be true
    end

    it 'returns false when member_id does not match' do
      result = described_class.exists_for?(
        member_id: "M000",
        case_number: "C-999",
        certification_date: "2025-01-15"
      )

      expect(result).to be false
    end

    it 'returns false when case_number does not match' do
      result = described_class.exists_for?(
        member_id: "M999",
        case_number: "C-000",
        certification_date: "2025-01-15"
      )

      expect(result).to be false
    end

    it 'returns false when certification_date does not match' do
      result = described_class.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: "2025-01-20"
      )

      expect(result).to be false
    end

    it 'handles Date objects' do
      result = described_class.exists_for?(
        member_id: "M999",
        case_number: "C-999",
        certification_date: Date.parse("2025-01-15")
      )

      expect(result).to be true
    end
  end

  describe '.from_batch_upload' do
    let(:user) { create(:user) }
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }
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
      results = described_class.from_batch_upload(batch_upload.id)

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

  describe 'outcome' do
    let(:certification) { create(:certification) }

    before { allow(Strata::EventManager).to receive(:publish) }

    it 'returns nil if no determination' do
      expect(certification.outcome).to be_nil
    end

    it 'returns appropriate exemption outcome' do
      determination = create(:determination,
                              subject: certification,
                              outcome: 'exempt',
                              decision_method: 'automated',
                              reasons: [ 'age_under_19_exempt' ],
                              created_at: 2.days.ago)
      outcome = certification.outcome
      expect(outcome.status).to eq 'exempt'
      expect(outcome.reason).to eq 'age_under_19_exempt'
      expect(outcome.source).to eq 'api'
      expect(outcome.timestamp).to eq determination.created_at
    end

    it 'returns appropriate compliant outcome' do
      determination = create(:determination,
                              subject: certification,
                              outcome: 'compliant',
                              decision_method: 'automated',
                              reasons: [ 'hours_reported_compliant' ],
                              created_at: 2.days.ago)
      outcome = certification.outcome
      expect(outcome.status).to eq 'compliant'
      expect(outcome.reason).to eq 'hours_reported_compliant'
      expect(outcome.source).to eq 'api'
      expect(outcome.timestamp).to eq determination.created_at
    end

    it 'returns appropriate indeterminate outcome' do
      determination = create(:determination,
                              subject: certification,
                              outcome: 'not_compliant',
                              decision_method: 'automated',
                              reasons: [ 'hours_reported_insufficient', 'income_reported_insufficient' ],
                              created_at: 2.days.ago)
      outcome = certification.outcome
      expect(outcome.status).to eq 'indeterminate'
      expect(outcome.reason).to eq ''
      expect(outcome.source).to eq ''
      expect(outcome.timestamp).to eq determination.created_at
    end

    it 'returns appropriate not compliant outcome' do
      determination = create(:determination,
                              subject: certification,
                              outcome: 'not_compliant',
                              decision_method: 'manual',
                              reasons: [ 'hours_reported_insufficient', 'income_reported_insufficient' ],
                              created_at: 2.days.ago)
      outcome = certification.outcome
      expect(outcome.status).to eq 'not_compliant'
      expect(outcome.reason).to eq ''
      expect(outcome.source).to eq ''
      expect(outcome.timestamp).to eq determination.created_at
    end

    context 'with multiple determinations' do
      before do
        create(:determination,
               subject: certification,
               outcome: 'not_compliant',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 2.days.ago)
        create(:determination,
               subject: certification,
               outcome: 'compliant',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 1.day.ago)
      end

      it 'returns most recent determination outcome' do
        expect(certification.outcome).not_to be_nil
        expect(certification.outcome.status).to eq 'compliant'
      end
    end
  end
end
