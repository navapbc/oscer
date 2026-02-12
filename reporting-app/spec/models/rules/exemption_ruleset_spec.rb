# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rules::ExemptionRuleset do
  let(:ruleset) { described_class.new }

  describe '#age_under_19' do
    context 'when age is nil' do
      it 'returns nil' do
        expect(ruleset.age_under_19(nil)).to be_nil
      end
    end

    context 'when age is less than 19' do
      it 'returns true' do
        expect(ruleset.age_under_19(18)).to be true
        expect(ruleset.age_under_19(0)).to be true
        expect(ruleset.age_under_19(1)).to be true
      end
    end

    context 'when age is 19 or greater' do
      it 'returns false' do
        expect(ruleset.age_under_19(19)).to be false
        expect(ruleset.age_under_19(64)).to be false
        expect(ruleset.age_under_19(65)).to be false
        expect(ruleset.age_under_19(100)).to be false
      end
    end
  end

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

  describe '#eligible_for_exemption' do
    context 'when all parameters are nil' do
      it 'returns nil' do
        expect(ruleset.eligible_for_exemption(nil, nil, nil, nil, nil)).to be_nil
      end
    end

    context 'when only is_pregnant is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, nil, true, nil, nil)).to be true
      end
    end

    context 'when only age_under_19 is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(true, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only age_over_65 is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, true, nil, nil, nil)).to be true
      end
    end

    context 'when only is_american_indian_or_alaska_native is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, nil, nil, true, nil)).to be true
      end
    end

    context 'when only is_veteran_with_disability is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, nil, nil, nil, true)).to be true
      end
    end

    context 'when age_under_19 and is_pregnant are both true' do
      it 'returns true (multiple reasons)' do
        expect(ruleset.eligible_for_exemption(true, nil, true, nil, nil)).to be true
      end
    end

    context 'when all are true' do
      it 'returns true (all reasons)' do
        expect(ruleset.eligible_for_exemption(true, true, true, true, true)).to be true
      end
    end

    context 'when all are false' do
      it 'returns false (no exemption)' do
        expect(ruleset.eligible_for_exemption(false, false, false, false, false)).to be false
      end
    end

    context 'when age-based exemption is false but is_american_indian_or_alaska_native is true' do
      it 'returns true (race-based exemption)' do
        expect(ruleset.eligible_for_exemption(false, false, false, true, nil)).to be true
      end
    end

    context 'when age-based exemption is false but pregnant is true' do
      it 'returns true (pregnant exemption)' do
        expect(ruleset.eligible_for_exemption(false, false, true, nil, nil)).to be true
      end
    end
  end
end
