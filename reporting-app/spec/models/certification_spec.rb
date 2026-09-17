# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Certification, type: :model do
  describe 'application_date validation' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'rejects a new certification with no application date' do
      certification = build(:certification, application_date: nil)

      expect(certification.save).to be false
      expect(certification.errors[:application_date]).to include("can't be blank")
    end

    it 'accepts a new certification with an application date' do
      certification = build(:certification, application_date: Date.new(2026, 1, 15))

      expect(certification.save).to be true
    end

    # The column is nullable and was never backfilled, so rows that already carry nil have to
    # stay updatable. An unconditional presence validation would lock them.
    it 'still saves an existing certification whose application date is nil' do
      certification = build(:certification, application_date: nil)
      certification.save(validate: false)

      certification.case_number = "C-updated"

      expect(certification.save).to be true
      expect(certification.reload.case_number).to eq("C-updated")
    end
  end

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

  describe '.find_duplicate' do
    let(:application_date) { Date.new(2025, 3, 1) }
    let!(:certification) do
      create(:certification,
        member_id: "M123",
        case_number: "C-123",
        application_date: application_date
      )
    end

    it 'returns the matching certification for the full compound key' do
      result = described_class.find_duplicate(
        member_id: "M123",
        case_number: "C-123",
        application_date: application_date
      )

      expect(result).to eq(certification)
    end

    it 'returns nil when the application_date does not match' do
      result = described_class.find_duplicate(
        member_id: "M123",
        case_number: "C-123",
        application_date: application_date + 1
      )

      expect(result).to be_nil
    end

    it 'returns nil when member_id does not match' do
      result = described_class.find_duplicate(
        member_id: "M000",
        case_number: "C-123",
        application_date: application_date
      )

      expect(result).to be_nil
    end

    it 'returns nil when any key component is blank' do
      expect(
        described_class.find_duplicate(member_id: "M123", case_number: "C-123", application_date: nil)
      ).to be_nil
      expect(
        described_class.find_duplicate(member_id: nil, case_number: "C-123", application_date: application_date)
      ).to be_nil
      expect(
        described_class.find_duplicate(member_id: "M123", case_number: "", application_date: application_date)
      ).to be_nil
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

  describe '#evaluated_month' do
    it 'returns the first of the month the member applied in' do
      certification = build(:certification, application_date: Date.new(2026, 1, 15))

      expect(certification.evaluated_month).to eq(Date.new(2026, 1, 1))
    end

    it 'returns nil when the certification has no application date' do
      certification = build(:certification, application_date: nil)

      expect(certification.evaluated_month).to be_nil
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
                              reasons: [ 'age_under_19_excluded' ],
                              created_at: 2.days.ago)
      outcome = certification.outcome
      expect(outcome.status).to eq 'exempt'
      expect(outcome.reason).to eq 'age_under_19_excluded'
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
      expect(outcome.reason).to be_nil
      expect(outcome.source).to be_nil
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
      expect(outcome.reason).to be_nil
      expect(outcome.source).to be_nil
      expect(outcome.timestamp).to eq determination.created_at
    end

    context 'with multiple determinations' do
      before do
        create(:determination,
               subject: certification,
               outcome: 'not_compliant',
               reasons: [ 'hours_reported_insufficient' ],
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
