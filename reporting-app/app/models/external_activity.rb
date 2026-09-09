# frozen_string_literal: true

# ExternalActivity stores trusted hours and/or gross income data from external sources, like the
# state system. A single row may report hours, income, or both — states report hours and earnings
# for the same job over the same period, and one row keeps that pairing intact.
#
# These are automated or external figures as opposed to member reported ones from
# ActivityReportApplicationForm. External data is auto-verified and doesn't require staff review.
#
# Activities are linked to certifications through member_id - since there's only one active
# certification per member at a time, the relationship is implicit.
#
# Supersedes ExternalHourlyActivity and ExternalIncomeActivity, which remain as read-only stubs
# over their retained tables. See docs/architecture/income-data/income-data.md.
#
# Append-only policy: Normal intake flows create records only. Updates or deletes are exceptional
# (e.g., corrections, backfills) and must be fully audited.
#
class ExternalActivity < ApplicationRecord
  include Strata::Attributes

  # Shared with member-reported Activity via ActivityCategories; household is external-only,
  # since a member never reports another household member's income as their own activity.
  CATEGORY_HOUSEHOLD = "household"
  ALLOWED_CATEGORIES = (ActivityCategories::ALL + [ CATEGORY_HOUSEHOLD ]).freeze

  SOURCE_TYPES = {
    api: "api",
    batch: "batch_upload"
  }.freeze
  ALLOWED_SOURCE_TYPES = SOURCE_TYPES.values.freeze

  HOURS_PER_DAY = 24

  # --- Strata Attributes ---

  # DateRange provides built-in validation (start <= end)
  strata_attribute :period, :us_date, range: true

  # --- Validations ---

  validates :member_id, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  # allow_nil rather than presence: each value is individually optional, and the pair is required
  # by hours_or_gross_income_present below.
  validates :hours, numericality: { greater_than: 0 }, allow_nil: true
  validates :gross_income, numericality: { greater_than: 0 }, allow_nil: true
  validate :hours_or_gross_income_present
  validate :hours_within_period
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :source_type, presence: true, inclusion: { in: ALLOWED_SOURCE_TYPES }
  validates :reported_at, presence: true

  # --- Scopes ---

  scope :for_member, ->(member_id) { where(member_id: member_id) }

  scope :within_period, ->(lookback_period) {
    return all unless lookback_period.present?

    start_date = lookback_period.start.to_date
    end_date = lookback_period.end.to_date.end_of_month

    where("period_start >= ? AND period_end <= ?", start_date, end_date)
  }

  # A row reporting both values belongs to both scopes: it contributes to both compliance tracks.
  scope :with_hours, -> { where.not(hours: nil) }
  scope :with_income, -> { where.not(gross_income: nil) }

  def month
    period_start.beginning_of_month
  end

  def hours?
    hours.present?
  end

  def income?
    gross_income.present?
  end

  private

  def hours_or_gross_income_present
    return if hours? || income?

    errors.add(:base, :hours_or_gross_income_required)
  end

  # Catches implausible figures a flat annual ceiling would let through. Dates are inclusive,
  # matching how ActivityAggregator#month_periods treats them. A reversed period is left to the
  # strata_attribute range validator rather than reported twice.
  def hours_within_period
    return unless hours?
    return if period_start.blank? || period_end.blank? || period_end < period_start

    maximum = ((period_end - period_start).to_i + 1) * HOURS_PER_DAY
    return if hours <= maximum

    errors.add(:hours, :greater_than_period, maximum: maximum)
  end
end
