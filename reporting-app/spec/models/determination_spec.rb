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
        expect(described_class.outcomes.keys).to contain_exactly('compliant', 'exempt')
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
          activity_report_non_compliant
          exemption_request_compliant
          exemption_request_non_compliant
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
    end
  end
end
