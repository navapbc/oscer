# frozen_string_literal: true

class CertificationBatchUpload < ApplicationRecord
  # Status workflow for batch upload processing
  attribute :status, :string, default: :pending
  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

  # Source type indicates how the file was uploaded
  enum :source_type, { ui: "ui", api: "api", ftp: "ftp", storage_event: "storage_event" }

  attribute :num_rows, :integer, default: 0
  attribute :num_rows_processed, :integer, default: 0
  attribute :num_rows_succeeded, :integer, default: 0
  attribute :num_rows_errored, :integer, default: 0
  attribute :results, :jsonb, default: {}

  belongs_to :uploader, class_name: "User"
  has_one_attached :file

  validates :filename, presence: true
  validates :file, presence: true, on: :create

  default_scope { with_attached_file }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(uploader_id: user_id) }

  # Mark as processing and update timestamp
  def start_processing!
    update!(status: :processing, num_rows_processed: 0)
  end

  # Mark as completed with results
  def complete_processing!(num_rows_succeeded:, num_rows_errored:, results:)
    update!(
      status: :completed,
      num_rows_succeeded: num_rows_succeeded,
      num_rows_errored: num_rows_errored,
      results: results,
      processed_at: Time.current
    )
  end

  # Mark as failed with error details
  def fail_processing!(error_message:)
    update!(
      status: :failed,
      results: { error: error_message },
      processed_at: Time.current
    )
  end

  # Update progress during processing
  def update_progress!(num_rows_processed:)
    update!(num_rows_processed: num_rows_processed)
  end

  # Check if can be processed
  def processable?
    pending?
  end

  # Get certifications created from this batch upload
  # @return [ActiveRecord::Relation] Certifications from this batch
  def certifications
    Certification.from_batch_upload(id)
  end

  # Count of certifications created from this batch
  # @return [Integer] Number of certifications
  def certifications_count
    CertificationOrigin.from_batch_upload(id).count
  end

  # Check if this upload uses cloud storage directly (batch upload v2)
  # @return [Boolean] true if storage_key is present
  def uses_cloud_storage?
    storage_key.present?
  end

  # Check if this upload uses Active Storage (legacy v1 uploads)
  # @return [Boolean] true if file is attached and storage_key is blank
  def uses_active_storage?
    file.attached? && storage_key.blank?
  end
end
