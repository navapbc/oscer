# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Determination, type: :model do
  describe 'enums' do
    describe 'decision_method' do
      it 'defines the decision_method enum with correct values' do
        expect(described_class.decision_methods.keys).to contain_exactly('automated', 'manual')
      end
    end

    describe 'outcome' do
      it 'defines the outcome enum with correct values' do
        expect(described_class.outcomes.keys).to contain_exactly('compliant', 'exempt', 'not_compliant')
      end
    end
  end

  describe 'validations' do
    describe 'reasons' do
      it 'defines valid reason constants' do
        expected_reasons = %w[
          age_under_19_exempt
          age_over_65_exempt
          pregnancy_exempt
          american_indian_alaska_native_exempt
          income_reported_compliant
          hours_reported_compliant
          hours_reported_insufficient
          exemption_request_compliant
          hours_insufficient
        ]
        expect(Determination::VALID_REASONS).to match_array(expected_reasons)
      end

      it 'validates presence of reasons' do
        determination = build(:determination, reasons: nil)
        expect(determination).not_to be_valid
        expect(determination.errors[:reasons]).to be_present
      end

      it 'validates presence of non-empty reasons array' do
        determination = build(:determination, reasons: [])
        expect(determination).not_to be_valid
        expect(determination.errors[:reasons]).to be_present
      end

      it 'allows valid reasons' do
        determination = build(:determination, reasons: [ 'age_under_19_exempt' ])
        expect(determination).to be_valid
      end

      it 'allows multiple valid reasons' do
        determination = build(:determination, reasons: [ 'age_under_19_exempt', 'pregnancy_exempt' ])
        expect(determination).to be_valid
      end

      it 'rejects invalid reasons' do
        determination = build(:determination, reasons: [ 'invalid_reason' ])
        expect(determination).not_to be_valid
        expect(determination.errors[:reasons]).to include(match(/must contain only valid reason values/))
      end

      it 'rejects mixed valid and invalid reasons' do
        determination = build(:determination, reasons: [ 'age_under_19_exempt', 'invalid_reason' ])
        expect(determination).not_to be_valid
        expect(determination.errors[:reasons]).to include(match(/must contain only valid reason values/))
      end

      it 'accepts hours_reported_compliant' do
        determination = build(:determination, reasons: [ 'hours_reported_compliant' ])
        expect(determination).to be_valid
      end

      it 'accepts hours_insufficient' do
        determination = build(:determination, reasons: [ 'hours_reported_insufficient' ])
        expect(determination).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_certifications' do
      let(:compliant_cert) { create(:certification) }
      let(:exempt_cert) { create(:certification) }

      before do
        create(:determination, subject: compliant_cert, outcome: 'compliant', reasons: [ 'hours_reported_compliant' ])
        create(:determination, subject: exempt_cert, outcome: 'exempt', reasons: [ 'age_under_19_exempt' ])
      end

      it 'returns determinations for specified certification IDs' do
        determinations = described_class.for_certifications([ compliant_cert.id, exempt_cert.id ])
        expect(determinations.pluck(:subject_id)).to contain_exactly(compliant_cert.id, exempt_cert.id)
      end

      it 'returns empty result when no matching certification IDs' do
        determinations = described_class.for_certifications([ SecureRandom.uuid ])
        expect(determinations).to be_empty
      end

      it 'filters by subject_type of Certification' do
        # This scope is designed specifically for Certifications
        determinations = described_class.for_certifications([ compliant_cert.id ])
        expect(determinations.all? { |d| d.subject_type == 'Certification' }).to be true
      end

      it 'chains with other scopes' do
        determinations = described_class.for_certifications([ compliant_cert.id, exempt_cert.id ]).where(outcome: 'exempt')
        expect(determinations.count).to eq(1)
        expect(determinations.first.outcome).to eq('exempt')
      end
    end

    describe '.latest_per_subject' do
      let(:compliant_cert) { create(:certification) }
      let(:exempt_cert) { create(:certification) }

      before do
        # Create multiple determinations for compliant_cert
        create(:determination,
               subject: compliant_cert,
               outcome: 'exempt',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 3.days.ago)
        create(:determination,
               subject: compliant_cert,
               outcome: 'compliant',
               reasons: [ 'age_under_19_exempt' ],
               created_at: 2.days.ago)

        # Create multiple determinations for exempt_cert
        create(:determination,
               subject: exempt_cert,
               outcome: 'compliant',
               reasons: [ 'income_reported_compliant' ],
               created_at: 2.days.ago)
        create(:determination,
               subject: exempt_cert,
               outcome: 'exempt',
               reasons: [ 'pregnancy_exempt' ],
               created_at: 1.day.ago)
      end

      it 'returns only the most recent determination per subject' do
        determinations = described_class.latest_per_subject.to_a
        expect(determinations.size).to eq(2)
      end

      it 'returns the most recent determination for each subject' do
        determinations = described_class.latest_per_subject.index_by(&:subject_id)

        # compliant_cert should have the not_compliant determination (most recent)
        compliant_cert_det = determinations[compliant_cert.id]
        expect(compliant_cert_det.outcome).to eq('compliant')
        expect(compliant_cert_det.created_at).to be_within(1.second).of(2.days.ago)

        # exempt_cert should have the exempt determination (most recent)
        exempt_cert_det = determinations[exempt_cert.id]
        expect(exempt_cert_det.outcome).to eq('exempt')
        expect(exempt_cert_det.created_at).to be_within(1.second).of(1.day.ago)
      end

      it 'works with a single subject' do
        determinations = described_class.where(subject_id: compliant_cert.id).latest_per_subject.to_a
        expect(determinations.size).to eq(1)
        expect(determinations.first.outcome).to eq('compliant')
      end

      it 'chains with for_certifications scope' do
        determinations = described_class.for_certifications([ compliant_cert.id, exempt_cert.id ]).latest_per_subject.to_a
        expect(determinations.size).to eq(2)
        expect(determinations.map(&:outcome)).to contain_exactly('compliant', 'exempt')
      end

      it 'maintains correct ordering when multiple subjects exist' do
        # Ensure all results have expected structure and no duplicates per subject
        determinations = described_class.latest_per_subject.group_by(&:subject_id)
        expect(determinations.values.all? { |dets| dets.size == 1 }).to be true
      end
    end

    describe '.for_certifications and .latest_per_subject together' do
      let(:compliant_cert) { create(:certification) }
      let(:exempt_cert) { create(:certification) }
      let(:cert3) { create(:certification) }

      before do
        # compliant_cert: 3 determinations (oldest to newest: compliant, exempt, not_compliant)
        create(:determination,
               subject: compliant_cert,
               outcome: 'compliant',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 3.days.ago)
        create(:determination,
               subject: compliant_cert,
               outcome: 'exempt',
               reasons: [ 'age_under_19_exempt' ],
               created_at: 2.days.ago)
        create(:determination,
               subject: compliant_cert,
               outcome: 'not_compliant',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 1.day.ago)

        # exempt_cert: 2 determinations
        create(:determination,
               subject: exempt_cert,
               outcome: 'compliant',
               reasons: [ 'income_reported_compliant' ],
               created_at: 2.days.ago)
        create(:determination,
               subject: exempt_cert,
               outcome: 'exempt',
               reasons: [ 'pregnancy_exempt' ],
               created_at: 1.day.ago)

        # cert3: 1 determination
        create(:determination,
               subject: cert3,
               outcome: 'compliant',
               reasons: [ 'hours_reported_compliant' ],
               created_at: 1.day.ago)
      end

      it 'returns latest determination for only specified certifications' do
        determinations = described_class.for_certifications([ compliant_cert.id, exempt_cert.id ]).latest_per_subject.to_a
        expect(determinations.size).to eq(2)
        expect(determinations.map(&:subject_id)).to contain_exactly(compliant_cert.id, exempt_cert.id)
      end

      it 'returns latest determinations with correct outcomes' do
        determinations = described_class.for_certifications([ compliant_cert.id, exempt_cert.id, cert3.id ]).latest_per_subject
        outcomes_by_subject = determinations.index_by(&:subject_id).transform_values(&:outcome)

        expect(outcomes_by_subject[compliant_cert.id]).to eq('not_compliant')
        expect(outcomes_by_subject[exempt_cert.id]).to eq('exempt')
        expect(outcomes_by_subject[cert3.id]).to eq('compliant')
      end

      it 'can be used for efficient batch status determination' do
        cert_ids = [ compliant_cert.id, exempt_cert.id ]
        determinations = described_class.for_certifications(cert_ids).latest_per_subject.index_by(&:subject_id)

        # Simulate looking up latest determination for a batch
        expect(determinations[compliant_cert.id].outcome).to eq('not_compliant')
        expect(determinations[exempt_cert.id].outcome).to eq('exempt')
        expect(determinations[cert3.id]).to be_nil
      end
    end
  end
end
