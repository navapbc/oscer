# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalActivity, type: :model do
  describe 'factory' do
    it 'creates a valid hours-only record' do
      expect(build(:external_activity, :with_hours)).to be_valid
    end

    it 'creates a valid income-only record' do
      expect(build(:external_activity, :with_income)).to be_valid
    end

    it 'creates a valid record carrying both hours and income' do
      expect(build(:external_activity, :with_hours_and_income)).to be_valid
    end

    it 'creates a valid household income record' do
      expect(build(:external_activity, :household)).to be_valid
    end
  end

  describe 'validations' do
    subject(:activity) { build(:external_activity, :with_hours) }

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

      it 'accepts every allowed category' do
        ExternalActivity::ALLOWED_CATEGORIES.each do |category|
          activity.category = category
          expect(activity).to be_valid
        end
      end

      it 'accepts the household category' do
        activity.category = ExternalActivity::CATEGORY_HOUSEHOLD
        expect(activity).to be_valid
      end

      it 'rejects unknown categories' do
        activity.category = 'invalid_category'
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include('is not included in the list')
      end
    end

    describe 'hours and gross_income' do
      it 'accepts a row reporting hours only' do
        expect(build(:external_activity, :with_hours)).to be_valid
      end

      it 'accepts a row reporting income only' do
        expect(build(:external_activity, :with_income)).to be_valid
      end

      it 'accepts a row reporting both' do
        expect(build(:external_activity, hours: 40, gross_income: 620)).to be_valid
      end

      it 'rejects a row reporting neither' do
        activity = build(:external_activity)

        expect(activity).not_to be_valid
        expect(activity.errors[:base]).to include('must report hours, gross income, or both')
      end

      it 'is enforced by the database when validations are bypassed' do
        activity = build(:external_activity)

        expect { activity.save(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /external_activities_hours_or_income/)
      end

      it 'rejects zero hours' do
        activity.hours = 0
        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include('must be greater than 0')
      end

      it 'rejects zero gross_income' do
        activity = build(:external_activity, :with_income, gross_income: 0)
        expect(activity).not_to be_valid
        expect(activity.errors[:gross_income]).to include('must be greater than 0')
      end

      it 'rejects negative hours' do
        activity.hours = -1
        expect(activity).not_to be_valid
      end
    end

    describe 'hours against the reported period' do
      # The ceiling is the wall-clock hours the period contains, so implausible hours are caught
      # even when they are well under a year's worth.
      it 'accepts hours equal to the hours the period contains' do
        activity = build(:external_activity,
                         period_start: Date.new(2026, 1, 1),
                         period_end: Date.new(2026, 1, 7),
                         hours: 7 * 24)

        expect(activity).to be_valid
      end

      it 'rejects hours exceeding a one-week period' do
        activity = build(:external_activity,
                         period_start: Date.new(2026, 1, 1),
                         period_end: Date.new(2026, 1, 7),
                         hours: 500)

        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include('cannot exceed 168 hours for the reported period')
      end

      it 'rejects more than 24 hours in a single-day period' do
        activity = build(:external_activity,
                         period_start: Date.new(2026, 1, 1),
                         period_end: Date.new(2026, 1, 1),
                         hours: 25)

        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include('cannot exceed 24 hours for the reported period')
      end

      it 'accepts 24 hours in a single-day period' do
        activity = build(:external_activity,
                         period_start: Date.new(2026, 1, 1),
                         period_end: Date.new(2026, 1, 1),
                         hours: 24)

        expect(activity).to be_valid
      end

      it 'does not constrain gross_income' do
        activity = build(:external_activity, :with_income,
                         period_start: Date.new(2026, 1, 1),
                         period_end: Date.new(2026, 1, 1),
                         gross_income: 10_000)

        expect(activity).to be_valid
      end

      # The range validator owns reversed periods; reporting a negative ceiling on top of it
      # would say the same thing twice.
      it 'leaves a reversed period to the period validator' do
        activity = build(:external_activity, hours: 5_000)
        activity.period = Strata::DateRange.new(
          start: Strata::USDate.new(2026, 1, 31),
          end: Strata::USDate.new(2026, 1, 1)
        )

        expect(activity).not_to be_valid
        expect(activity.errors[:period]).to include('start date cannot be after end date')
        expect(activity.errors[:hours]).to be_empty
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
          start: Strata::USDate.new(2026, 1, 15),
          end: Strata::USDate.new(2026, 1, 1)
        )

        expect(activity).not_to be_valid
        expect(activity.errors[:period]).to include('start date cannot be after end date')
      end

      it 'accepts period_end equal to period_start' do
        activity.period = Strata::DateRange.new(
          start: Strata::USDate.new(2026, 1, 15),
          end: Strata::USDate.new(2026, 1, 15)
        )
        activity.hours = 8

        expect(activity).to be_valid
      end
    end

    describe 'source_type' do
      it 'is required' do
        activity.source_type = nil
        expect(activity).not_to be_valid
      end

      it 'accepts every allowed source type' do
        ExternalActivity::ALLOWED_SOURCE_TYPES.each do |source_type|
          activity.source_type = source_type
          expect(activity).to be_valid
        end
      end

      it 'accepts a batch upload row' do
        expect(build(:external_activity, :with_hours, :from_batch)).to be_valid
      end

      it 'rejects unknown source types' do
        activity.source_type = 'invalid'
        expect(activity).not_to be_valid
      end
    end

    describe 'reported_at' do
      it 'is required' do
        activity.reported_at = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:reported_at]).to include("can't be blank")
      end
    end
  end

  describe 'scopes' do
    describe '.for_member' do
      it 'returns entries for the given member' do
        entry = create(:external_activity, :with_hours, member_id: 'M12345')
        create(:external_activity, :with_hours, member_id: 'OTHER')

        expect(described_class.for_member('M12345')).to eq([ entry ])
      end
    end

    describe '.within_period' do
      let(:lookback) do
        Strata::DateRange.new(
          start: Strata::USDate.new(2026, 1, 1),
          end: Strata::USDate.new(2026, 3, 31)
        )
      end

      it 'returns all when lookback_period is nil' do
        create(:external_activity, :with_hours,
               period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31))

        expect(described_class.within_period(nil).count).to eq(1)
      end

      it 'returns all when lookback_period is blank' do
        create(:external_activity, :with_hours)

        expect(described_class.within_period('').count).to eq(1)
      end

      it 'includes records fully inside the lookback window' do
        inside = create(:external_activity, :with_hours,
                        period_start: Date.new(2026, 2, 1), period_end: Date.new(2026, 2, 28))

        expect(described_class.within_period(lookback)).to include(inside)
      end

      it 'excludes records that extend before the lookback start' do
        create(:external_activity, :with_hours,
               period_start: Date.new(2025, 12, 1), period_end: Date.new(2026, 2, 28))

        expect(described_class.within_period(lookback)).to be_empty
      end

      it 'excludes records that extend after the lookback end' do
        create(:external_activity, :with_hours,
               period_start: Date.new(2026, 3, 1), period_end: Date.new(2026, 5, 31))

        expect(described_class.within_period(lookback)).to be_empty
      end

      # The lookback end is widened to the end of its month before comparing.
      it 'includes a record ending later in the lookback end month' do
        inside = create(:external_activity, :with_hours,
                        period_start: Date.new(2026, 3, 1), period_end: Date.new(2026, 3, 31))
        partial_lookback = Strata::DateRange.new(
          start: Strata::USDate.new(2026, 1, 1),
          end: Strata::USDate.new(2026, 3, 15)
        )

        expect(described_class.within_period(partial_lookback)).to include(inside)
      end
    end

    # A combined row contributes to both compliance tracks, so it belongs to both scopes.
    describe '.with_hours and .with_income' do
      let!(:hours_only) { create(:external_activity, :with_hours) }
      let!(:income_only) { create(:external_activity, :with_income) }
      let!(:combined) { create(:external_activity, :with_hours_and_income) }

      it '.with_hours includes hours-only and combined rows' do
        expect(described_class.with_hours).to contain_exactly(hours_only, combined)
      end

      it '.with_hours excludes income-only rows' do
        expect(described_class.with_hours).not_to include(income_only)
      end

      it '.with_income includes income-only and combined rows' do
        expect(described_class.with_income).to contain_exactly(income_only, combined)
      end

      it '.with_income excludes hours-only rows' do
        expect(described_class.with_income).not_to include(hours_only)
      end

      it 'chains to select only combined rows' do
        expect(described_class.with_hours.with_income).to contain_exactly(combined)
      end
    end
  end

  describe '#month' do
    it 'returns the first day of the period start month' do
      activity = build(:external_activity, :with_hours,
                       period_start: Date.new(2026, 2, 14), period_end: Date.new(2026, 2, 28))

      expect(activity.month).to eq(Date.new(2026, 2, 1))
    end
  end

  describe '#hours? and #income?' do
    it 'reports which values an hours-only row carries' do
      activity = build(:external_activity, :with_hours)

      expect(activity.hours?).to be(true)
      expect(activity.income?).to be(false)
    end

    it 'reports which values an income-only row carries' do
      activity = build(:external_activity, :with_income)

      expect(activity.hours?).to be(false)
      expect(activity.income?).to be(true)
    end

    it 'reports both for a combined row' do
      activity = build(:external_activity, :with_hours_and_income)

      expect(activity.hours?).to be(true)
      expect(activity.income?).to be(true)
    end
  end

  describe 'constants' do
    it 'defines ALLOWED_CATEGORIES as the shared categories plus household' do
      expect(ExternalActivity::ALLOWED_CATEGORIES)
        .to eq(%w[employment community_service education unearned household])
    end

    it 'defines the API and batch source types' do
      expect(ExternalActivity::SOURCE_TYPES[:api]).to eq('api')
      expect(ExternalActivity::SOURCE_TYPES[:batch]).to eq('batch_upload')
    end
  end

  describe 'i18n contract for source_type' do
    it 'has a certification_cases.income.source_types entry for each allowed source type' do
      ExternalActivity::ALLOWED_SOURCE_TYPES.each do |source_type|
        key = "certification_cases.income.source_types.#{source_type}"
        expect(I18n.exists?(key.to_sym, :en)).to be(true),
          "Missing locale :en key #{key.inspect} for ExternalActivity source_type #{source_type.inspect}"
      end
    end
  end
end
