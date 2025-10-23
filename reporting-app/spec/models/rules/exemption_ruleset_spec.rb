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

  describe '#age_65_or_older' do
    context 'when age is nil' do
      it 'returns nil' do
        expect(ruleset.age_65_or_older(nil)).to be_nil
      end
    end

    context 'when age is 65 or greater' do
      it 'returns true' do
        expect(ruleset.age_65_or_older(65)).to be true
        expect(ruleset.age_65_or_older(100)).to be true
      end
    end

    context 'when age is less than 65' do
      it 'returns false' do
        expect(ruleset.age_65_or_older(0)).to be false
        expect(ruleset.age_65_or_older(18)).to be false
        expect(ruleset.age_65_or_older(64)).to be false
      end
    end
  end

  describe '#eligible_for_age_exemption' do
    context 'when both parameters are nil' do
      it 'returns nil' do
        expect(ruleset.eligible_for_age_exemption(nil, nil)).to be_nil
      end
    end

    context 'when age_under_19 is nil and age_65_or_older is not nil' do
      it 'returns true' do
        expect(ruleset.eligible_for_age_exemption(nil, true)).to be true
      end

      it 'returns false' do
        expect(ruleset.eligible_for_age_exemption(nil, false)).to be false
      end
    end

    context 'when age_under_19 is not nil and age_65_or_older is nil' do
      it 'returns true' do
        expect(ruleset.eligible_for_age_exemption(true, nil)).to be true
      end

      it 'returns false' do
        expect(ruleset.eligible_for_age_exemption(false, nil)).to be false
      end
    end

    context 'when age_under_19 is true' do
      it 'returns true (exempt)' do
        expect(ruleset.eligible_for_age_exemption(true, false)).to be true
        expect(ruleset.eligible_for_age_exemption(true, true)).to be true
      end
    end

    context 'when age_65_or_older is true' do
      it 'returns true (exempt)' do
        expect(ruleset.eligible_for_age_exemption(false, true)).to be true
        expect(ruleset.eligible_for_age_exemption(true, true)).to be true
      end
    end

    context 'when both are false' do
      it 'returns false (not exempt)' do
        expect(ruleset.eligible_for_age_exemption(false, false)).to be false
      end
    end
  end

  describe '#age (inherited from MedicaidRuleset)' do
    context 'when date_of_birth and evaluated_on are valid' do
      it 'calculates age correctly' do
        evaluated_on = Date.new(2025, 10, 23)
        date_of_birth = Date.new(2007, 10, 23)
        expect(ruleset.age(date_of_birth, evaluated_on)).to eq(18)
      end
    end

    context 'when birthday has not occurred yet this year' do
      it 'calculates age correctly' do
        evaluated_on = Date.new(2025, 10, 22)
        date_of_birth = Date.new(2007, 10, 23)
        expect(ruleset.age(date_of_birth, evaluated_on)).to eq(17)
      end
    end

    context 'when date_of_birth is nil' do
      it 'returns nil' do
        expect(ruleset.age(nil, Date.current)).to be_nil
      end
    end

    context 'when evaluated_on is nil' do
      it 'returns nil' do
        expect(ruleset.age(Date.current, nil)).to be_nil
      end
    end

    context 'when date_of_birth is after evaluated_on' do
      it 'returns nil' do
        evaluated_on = Date.new(2025, 10, 23)
        date_of_birth = Date.new(2026, 10, 23)
        expect(ruleset.age(date_of_birth, evaluated_on)).to be_nil
      end
    end
  end
end
