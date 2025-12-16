# frozen_string_literal: true

# ExParteActivity stores trusted hours data from the state system (ex parte verification).
#
# These are "ex parte" (automated/external) hours as opposed to member
# reported hours from ActivityReportApplicationForm. Ex parte hours are
# auto-verified and don't require staff review.
#
# Activities are linked to certifications through member_id - since there's
# only one active certification per member at a time, the relationship is implicit.
#
class ExParteActivity < ApplicationRecord
  include Strata::Attributes

  ALLOWED_CATEGORIES = ActivityCategories::ALL

  SOURCE_TYPES = {
    api: "api",
    batch: "batch_upload"
  }.freeze
  ALLOWED_SOURCE_TYPES = SOURCE_TYPES.values.freeze

  # 365 days * 24 hours = 8,760 hours
  MAX_HOURS_PER_YEAR = 365 * 24

  # --- Strata Attributes ---

  # DateRange provides built-in validation (start <= end)
  strata_attribute :period, :us_date, range: true

  # --- Validations ---

  validates :member_id, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  validates :hours, presence: true,
                    numericality: { greater_than: 0, less_than_or_equal_to: MAX_HOURS_PER_YEAR }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :source_type, presence: true, inclusion: { in: ALLOWED_SOURCE_TYPES }

  # --- Scopes ---

  scope :for_member, ->(member_id) { where(member_id: member_id) }

  scope :within_period, ->(lookback_period) {
    return all unless lookback_period.present?

    start_date = Date.parse(lookback_period.start.to_s)
    end_date = Date.parse(lookback_period.end.to_s).end_of_month

    where("period_start >= ? AND period_end <= ?", start_date, end_date)
  }
end
