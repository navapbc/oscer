# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activity, type: :model do
  describe 'validations' do
    let(:activity) { build(:work_activity) }

    describe 'category validation' do
      context 'when category is a valid value' do
        it 'validates with employment' do
          activity.category = 'employment'
          expect(activity).to be_valid
        end

        it 'validates with education' do
          activity.category = 'education'
          expect(activity).to be_valid
        end

        it 'validates with community_service' do
          activity.category = 'community_service'
          expect(activity).to be_valid
        end
      end

      context 'when category is an invalid value' do
        it 'is invalid with an unknown category' do
          activity.category = 'invalid_category'
          expect(activity).not_to be_valid
          expect(activity.errors[:category]).to include('is not included in the list')
        end
      end
    end

    describe 'name validation' do
      it 'is invalid when name is nil' do
        activity.name = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:name]).to include("can't be blank")
      end

      it 'is valid with a name' do
        activity.name = 'Test Activity'
        expect(activity).to be_valid
      end
    end
  end
end
