# frozen_string_literal: true

# Read-only stub over the retained external_hourly_activities table, superseded by ExternalActivity.
#
# No read path consults this table any more, so the readonly guard stops anything writing data the
# compliance calculations would never see. The class remains so pre-consolidation rows stay
# queryable until the backfill folds them into external_activities.
# See docs/architecture/income-data/income-data.md.
class ExternalHourlyActivity < ApplicationRecord
  scope :for_member, ->(member_id) { where(member_id: member_id) }

  def readonly?
    true
  end
end
