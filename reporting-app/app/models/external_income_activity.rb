# frozen_string_literal: true

# ExternalIncomeActivity stores trusted gross income data from external sources,
# parallel to ExternalHourlyActivity for hours.
#
# Schema: Records use member_id only (like ExternalHourlyActivity). There is no certification_id
# column; the active certification for a member is implicit. Do not add belongs_to :certification
# if a future migration adds an optional UUID for traceability—use a plain column only.
#
# Append-only policy: Normal intake flows create records only. Updates or deletes are
# exceptional (e.g., corrections, backfills) and must be fully audited—see
# docs/architecture/income-data/income-data.md (Audit trail over hard immutability).
#
class ExternalIncomeActivity < ApplicationRecord
  include Strata::Attributes

  ALLOWED_CATEGORIES = ActivityCategories::ALL

  SOURCE_TYPES = {
    api: "api"
  }.freeze
  ALLOWED_SOURCE_TYPES = SOURCE_TYPES.values.freeze

  # --- Strata Attributes ---

  strata_attribute :period, :us_date, range: true

  # --- Validations ---

  validates :member_id, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  validates :gross_income, presence: true,
                           numericality: { greater_than: 0 }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :source_type, presence: true, inclusion: { in: ALLOWED_SOURCE_TYPES }
  validates :reported_at, presence: true

  # --- Scopes ---

  scope :for_member, ->(member_id) { where(member_id: member_id) }

  scope :within_period, ->(lookback_period) {
    return all unless lookback_period.present?

    start_date = Date.parse(lookback_period.start.to_s)
    end_date = Date.parse(lookback_period.end.to_s).end_of_month

    where("period_start >= ? AND period_end <= ?", start_date, end_date)
  }
end
