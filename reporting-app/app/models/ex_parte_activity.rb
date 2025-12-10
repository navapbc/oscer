# frozen_string_literal: true

# ExParteActivity stores trusted hours data from the state system (ex parte verification).
#
# These are "ex parte" (automated/external) hours as opposed to member
# reported hours from ActivityReportApplicationForm. Ex parte hours are
# auto-verified and don't require staff review.
#
# @note The `outside_period` flag should be set by the service layer
#   (ExParteActivityService) when creating entries, not by callbacks.
#
class ExParteActivity < ApplicationRecord
  ALLOWED_CATEGORIES = %w[employment community_service education].freeze

  SOURCE_TYPES = {
    api: "api",
    batch: "batch_upload"
  }.freeze
  ALLOWED_SOURCE_TYPES = SOURCE_TYPES.values.freeze

  # 365 days * 24 hours = 8,760 hours
  MAX_HOURS_PER_YEAR = 365 * 24

  # --- Validations ---

  validates :member_id, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  validates :hours, presence: true,
                    numericality: { greater_than: 0, less_than_or_equal_to: MAX_HOURS_PER_YEAR }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :source_type, presence: true, inclusion: { in: ALLOWED_SOURCE_TYPES }

  validate :period_end_after_start

  # --- Scopes ---

  scope :for_certification, ->(cert_id) { where(certification_id: cert_id) }
  scope :pending_for_member, ->(member_id) { where(member_id: member_id, certification_id: nil) }

  # --- Instance Methods ---

  def pending?
    certification_id.nil?
  end

  def link_to_certification!(cert_id)
    update!(certification_id: cert_id)
  end

  private

  def period_end_after_start
    return unless period_start && period_end

    errors.add(:period_end, "must be on or after period start") if period_end < period_start
  end
end
