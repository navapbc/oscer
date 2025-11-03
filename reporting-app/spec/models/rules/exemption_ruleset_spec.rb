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

  describe '#pregnant' do
    context 'when pregnancy_status is nil' do
      it 'returns nil' do
        expect(ruleset.pregnant(nil)).to be_nil
      end
    end

    context 'when pregnancy_status is true' do
      it 'returns true' do
        expect(ruleset.pregnant(true)).to be true
      end
    end

    context 'when pregnancy_status is false' do
      it 'returns false' do
        expect(ruleset.pregnant(false)).to be false
      end
    end
  end

  describe '#eligible_for_exemption' do
    context 'when all parameters are nil' do
      it 'returns nil' do
        expect(ruleset.eligible_for_exemption(nil, nil, nil)).to be_nil
      end
    end

    context 'when only pregnant is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, nil, true)).to be true
      end
    end

    context 'when only age_under_19 is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(true, nil, nil)).to be true
      end
    end

    context 'when only age_over_65 is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exemption(nil, true, nil)).to be true
      end
    end

    context 'when age_under_19 and pregnant are both true' do
      it 'returns true (multiple reasons)' do
        expect(ruleset.eligible_for_exemption(true, nil, true)).to be true
      end
    end

    context 'when all are true' do
      it 'returns true (all reasons)' do
        expect(ruleset.eligible_for_exemption(true, true, true)).to be true
      end
    end

    context 'when all are false' do
      it 'returns false (no exemption)' do
        expect(ruleset.eligible_for_exemption(false, false, false)).to be false
      end
    end

    context 'when age-based exemption is false but pregnant is true' do
      it 'returns true (pregnant exemption)' do
        expect(ruleset.eligible_for_exemption(false, false, true)).to be true
      end
    end
  end
end
