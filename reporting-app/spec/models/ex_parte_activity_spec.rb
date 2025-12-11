# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExParteActivity, type: :model do
  describe 'factory' do
    it 'creates a valid record' do
      activity = build(:ex_parte_activity)
      expect(activity).to be_valid
    end

    it 'creates a valid record from batch' do
      activity = build(:ex_parte_activity, :from_batch)
      expect(activity).to be_valid
      expect(activity.source_type).to eq('batch_upload')
      expect(activity.source_id).to be_present
    end
  end

  describe 'validations' do
    subject(:activity) { build(:ex_parte_activity) }

    describe 'member_id' do
      it 'is required' do
        activity.member_id = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:member_id]).to include("can't be blank")
      end
    end

    describe 'category' do
      it 'is required' do
        activity.category = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include("can't be blank")
      end

      it 'accepts valid categories' do
        ExParteActivity::ALLOWED_CATEGORIES.each do |category|
          activity.category = category
          expect(activity).to be_valid
        end
      end

      it 'rejects invalid categories' do
        activity.category = 'invalid_category'
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include('is not included in the list')
      end
    end

    describe 'hours' do
      it 'is required' do
        activity.hours = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include("can't be blank")
      end

      it 'must be greater than 0' do
        activity.hours = 0
        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include('must be greater than 0')
      end

      it 'must be less than or equal to MAX_HOURS_PER_YEAR' do
        activity.hours = ExParteActivity::MAX_HOURS_PER_YEAR + 1
        expect(activity).not_to be_valid
      end

      it 'accepts valid hours' do
        activity.hours = 40.5
        expect(activity).to be_valid
      end
    end

    describe 'period dates' do
      it 'requires period_start' do
        activity.period_start = nil
        expect(activity).not_to be_valid
      end

      it 'requires period_end' do
        activity.period_end = nil
        expect(activity).not_to be_valid
      end

      it 'rejects period_end before period_start' do
        activity.period = Strata::DateRange.new(
          start: Strata::USDate.new(2025, 1, 15),
          end: Strata::USDate.new(2025, 1, 1)
        )
        expect(activity).not_to be_valid
        expect(activity.errors[:period]).to include('start date cannot be after end date')
      end

      it 'accepts period_end equal to period_start' do
        activity.period = Strata::DateRange.new(
          start: Strata::USDate.new(2025, 1, 15),
          end: Strata::USDate.new(2025, 1, 15)
        )
        expect(activity).to be_valid
      end
    end

    describe 'source_type' do
      it 'is required' do
        activity.source_type = nil
        expect(activity).not_to be_valid
      end

      it 'accepts valid source types' do
        ExParteActivity::ALLOWED_SOURCE_TYPES.each do |source|
          activity.source_type = source
          expect(activity).to be_valid
        end
      end

      it 'rejects invalid source types' do
        activity.source_type = 'invalid'
        expect(activity).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_member' do
      it 'returns entries for the given member' do
        member_id = 'M12345'
        entry = create(:ex_parte_activity, member_id: member_id)
        create(:ex_parte_activity, member_id: 'OTHER')

        expect(described_class.for_member(member_id)).to eq([ entry ])
      end
    end
  end

  describe 'constants' do
    it 'defines ALLOWED_CATEGORIES' do
      expect(ExParteActivity::ALLOWED_CATEGORIES).to eq(%w[employment community_service education])
    end

    it 'defines source type constants' do
      expect(ExParteActivity::SOURCE_TYPES[:api]).to eq('api')
      expect(ExParteActivity::SOURCE_TYPES[:batch]).to eq('batch_upload')
    end

    it 'defines MAX_HOURS_PER_YEAR' do
      expect(ExParteActivity::MAX_HOURS_PER_YEAR).to eq(8760)
    end
  end
end
