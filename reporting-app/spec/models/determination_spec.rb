# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Determination, type: :model do
  describe 'enums' do
    describe 'decision_method' do
      it 'defines the decision_method enum with correct values' do
        expect(described_class.decision_methods.keys).to contain_exactly('automated', 'manual')
      end
    end

    describe 'reason' do
      it 'defines the reason enum with correct values' do
        expected_reasons = %w[
          age_under_19_exempt
          age_over_65_exempt
          pregnancy_exempt
          american_indian_alaska_native_exempt
        ]
        expect(described_class.reasons.keys).to match_array(expected_reasons)
      end
    end

    describe 'outcome' do
      it 'defines the outcome enum with correct values' do
        expect(described_class.outcomes.keys).to contain_exactly('compliant', 'exempt')
      end
    end
  end
end
