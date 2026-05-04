# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalIncomeActivity, type: :model do
  describe 'factory' do
    it 'creates a valid record' do
      income = build(:external_income_activity)
      expect(income).to be_valid
    end
  end

  describe 'validations' do
    subject(:income) { build(:external_income_activity) }

    describe 'member_id' do
      it 'is required' do
        income.member_id = nil
        expect(income).not_to be_valid
        expect(income.errors[:member_id]).to include("can't be blank")
      end
    end

    describe 'category' do
      it 'is required' do
        income.category = nil
        expect(income).not_to be_valid
        expect(income.errors[:category]).to include("can't be blank")
      end

      it 'accepts valid categories' do
        ExternalIncomeActivity::ALLOWED_CATEGORIES.each do |category|
          income.category = category
          expect(income).to be_valid
        end
      end

      it 'rejects invalid categories' do
        income.category = 'invalid_category'
        expect(income).not_to be_valid
        expect(income.errors[:category]).to include('is not included in the list')
      end
    end

    describe 'gross_income' do
      it 'is required' do
        income.gross_income = nil
        expect(income).not_to be_valid
        expect(income.errors[:gross_income]).to include("can't be blank")
      end

      it 'must be greater than 0' do
        income.gross_income = 0
        expect(income).not_to be_valid
        expect(income.errors[:gross_income]).to include('must be greater than 0')
      end

      it 'accepts valid amounts' do
        income.gross_income = 580.50
        expect(income).to be_valid
      end
    end

    describe 'period dates' do
      it 'requires period_start' do
        income.period_start = nil
        expect(income).not_to be_valid
      end

      it 'requires period_end' do
        income.period_end = nil
        expect(income).not_to be_valid
      end

      it 'rejects period_end before period_start' do
        income.period = Strata::DateRange.new(
          start: Strata::USDate.new(2025, 1, 15),
          end: Strata::USDate.new(2025, 1, 1)
        )
        expect(income).not_to be_valid
        expect(income.errors[:period]).to include('start date cannot be after end date')
      end

      it 'accepts period_end equal to period_start' do
        income.period = Strata::DateRange.new(
          start: Strata::USDate.new(2025, 1, 15),
          end: Strata::USDate.new(2025, 1, 15)
        )
        expect(income).to be_valid
      end
    end

    describe 'source_type' do
      it 'is required' do
        income.source_type = nil
        expect(income).not_to be_valid
      end

      it 'accepts valid source types' do
        ExternalIncomeActivity::ALLOWED_SOURCE_TYPES.each do |source|
          income.source_type = source
          expect(income).to be_valid
        end
      end

      it 'rejects invalid source types' do
        income.source_type = 'invalid'
        expect(income).not_to be_valid
      end
    end

    describe 'reported_at' do
      it 'is required' do
        income.reported_at = nil
        expect(income).not_to be_valid
        expect(income.errors[:reported_at]).to include("can't be blank")
      end
    end
  end

  describe 'scopes' do
    describe '.for_member' do
      it 'returns entries for the given member' do
        member_id = 'M12345'
        entry = create(:external_income_activity, member_id: member_id)
        create(:external_income_activity, member_id: 'OTHER')

        expect(described_class.for_member(member_id)).to eq([ entry ])
      end
    end

    describe '.within_period' do
      let(:lookback) do
        Strata::DateRange.new(
          start: Strata::USDate.new(2025, 1, 1),
          end: Strata::USDate.new(2025, 3, 31)
        )
      end

      it 'returns all when lookback_period is nil' do
        create(:external_income_activity, period_start: Date.new(2024, 1, 1), period_end: Date.new(2024, 1, 31))

        expect(described_class.within_period(nil).count).to eq(1)
      end

      it 'returns all when lookback_period is blank' do
        create(:external_income_activity)

        expect(described_class.within_period("").count).to eq(1)
      end

      it 'includes records fully inside the lookback window' do
        inside = create(:external_income_activity,
                        period_start: Date.new(2025, 2, 1),
                        period_end: Date.new(2025, 2, 28))

        expect(described_class.within_period(lookback)).to include(inside)
      end

      it 'excludes records that extend before the lookback start' do
        create(:external_income_activity,
               period_start: Date.new(2024, 12, 1),
               period_end: Date.new(2025, 2, 28))

        expect(described_class.within_period(lookback)).to be_empty
      end

      it 'excludes records that extend after the lookback end' do
        create(:external_income_activity,
               period_start: Date.new(2025, 3, 1),
               period_end: Date.new(2025, 5, 31))

        expect(described_class.within_period(lookback)).to be_empty
      end
    end
  end

  describe 'constants' do
    it 'defines ALLOWED_CATEGORIES' do
      expect(ExternalIncomeActivity::ALLOWED_CATEGORIES).to eq(%w[employment community_service education])
    end

    it 'defines MVP source type strings' do
      expect(ExternalIncomeActivity::SOURCE_TYPES[:api]).to eq('api')
    end
  end
end
