# frozen_string_literal: true

# ExParteActivity stores hours data submitted via API or batch upload.
#
# These are "ex parte" (automated/external) hours as opposed to manually
# reported hours from ActivityReportApplicationForm. Ex parte hours are
# auto-verified and don't require staff review.
#
# @note The `outside_period` flag should be set by the service layer
#   (ExParteActivityService) when creating entries, not by callbacks.
#
class ExParteActivity < ApplicationRecord
  ALLOWED_CATEGORIES = %w[employment community_service education].freeze

  SOURCE_TYPE_API = "api"
  SOURCE_TYPE_BATCH = "batch_upload"
  ALLOWED_SOURCE_TYPES = [SOURCE_TYPE_API, SOURCE_TYPE_BATCH].freeze

  MAX_HOURS = 744

  # --- Associations ---

  belongs_to :certification, optional: true

  # --- Validations ---

  validates :member_id, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  validates :hours, presence: true,
                    numericality: { greater_than: 0, less_than_or_equal_to: MAX_HOURS }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :source_type, presence: true, inclusion: { in: ALLOWED_SOURCE_TYPES }
  validates :reported_at, presence: true

  validate :period_end_after_start

  # --- Scopes ---

  scope :for_certification, ->(cert_id) { where(certification_id: cert_id) }
  scope :pending_for_member, ->(member_id) { where(member_id: member_id, certification_id: nil) }
  scope :by_category, ->(category) { where(category: category) }
  scope :in_period, ->(start_date, end_date) { where("period_start <= ? AND period_end >= ?", end_date, start_date) }

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
