# frozen_string_literal: true

require 'rails_helper'

# ExternalHourlyActivity is a read-only stub over a retained table; ExternalActivity supersedes it.
RSpec.describe ExternalHourlyActivity, type: :model do
  # insert_all bypasses ActiveRecord write protection, which is the only way to seed a readonly
  # model — and the shape the backfill will use.
  def insert_row(member_id: 'M12345')
    described_class.insert_all!([
      { member_id: member_id, category: 'employment', hours: 40,
        period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31),
        source_type: 'api', created_at: Time.current, updated_at: Time.current }
    ])
  end

  it 'refuses to create rows' do
    expect {
      described_class.create!(member_id: 'M12345', category: 'employment', hours: 40,
                              period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31),
                              source_type: 'api')
    }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'refuses to update existing rows' do
    insert_row
    row = described_class.for_member('M12345').first

    expect { row.update!(hours: 10) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'still reads retained rows by member' do
    insert_row
    insert_row(member_id: 'OTHER')

    expect(described_class.for_member('M12345').map(&:hours)).to eq([ 40 ])
  end
end
