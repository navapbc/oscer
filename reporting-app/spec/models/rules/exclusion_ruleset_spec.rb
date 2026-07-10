# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rules::ExclusionRuleset do
  let(:ruleset) { described_class.new }

  describe '#is_pregnant' do
    context 'when pregnancy_status is nil' do
      it 'returns nil' do
        expect(ruleset.is_pregnant(nil)).to be_nil
      end
    end

    context 'when pregnancy_status is true' do
      it 'returns true' do
        expect(ruleset.is_pregnant(true)).to be true
      end
    end

    context 'when pregnancy_status is false' do
      it 'returns false' do
        expect(ruleset.is_pregnant(false)).to be false
      end
    end
  end

  describe '#is_american_indian_or_alaska_native' do
    context 'when race_ethnicity is nil' do
      it 'returns nil' do
        expect(ruleset.is_american_indian_or_alaska_native(nil)).to be_nil
      end
    end

    [
      "american_indian_or_alaska_native",
      "american_indian",
      "alaska_native",
      "AmErIcAn_InDiAn",
      "ALASKA_NATIVE",
      "american indian",
      "alaska native"
    ].each do |race_ethnicity_value|
      context "when race_ethnicity is #{race_ethnicity_value.inspect}" do
        it 'returns true' do
          expect(ruleset.is_american_indian_or_alaska_native(race_ethnicity_value)).to be true
        end
      end
    end

    context 'when race_ethnicity is another category' do
      it 'returns false' do
        expect(ruleset.is_american_indian_or_alaska_native("white")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("black_or_african_american")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("asian")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("native_hawaiian_or_other_pacific_islander")).to be false
      end
    end
  end

  describe '#is_veteran_with_disability' do
    context 'when rating_data is nil' do
      it 'returns nil' do
        expect(ruleset.is_veteran_with_disability(nil)).to be_nil
      end
    end

    context 'when rating is 100' do
      let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

      it 'returns true' do
        expect(ruleset.is_veteran_with_disability(rating_data)).to be true
      end
    end

    context 'when rating is not 100' do
      let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 70 } } } }

      it 'returns false' do
        expect(ruleset.is_veteran_with_disability(rating_data)).to be false
      end
    end

    context 'when rating data is missing attributes' do
      let(:rating_data) { { "data" => {} } }

      it 'returns false' do
        expect(ruleset.is_veteran_with_disability(rating_data)).to be false
      end
    end
  end

  describe '#eligible_for_exclusion' do
    context 'when all parameters are nil' do
      it 'returns nil' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil)).to be_nil
      end
    end

    context 'when only is_pregnant is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, nil, nil)).to be true
      end
    end

    context 'when only is_american_indian_or_alaska_native is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, true, nil)).to be true
      end
    end

    context 'when only is_veteran_with_disability is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, true)).to be true
      end
    end

    context 'when multiple parameters are true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, true, nil)).to be true
      end
    end

    context 'when all are true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, true, true)).to be true
      end
    end

    context 'when all are false' do
      it 'returns false' do
        expect(ruleset.eligible_for_exclusion(false, false, false)).to be false
      end
    end

    context 'when some are false but one is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(false, true, false)).to be true
      end
    end
  end
end
