# frozen_string_literal: true

class CertificationBatchUpload < ApplicationRecord
  # Status workflow for batch upload processing
  enum :status, {
    pending: 0,      # Uploaded, waiting to be processed
    processing: 1,   # Currently being processed by background job
    completed: 2,    # Processing finished successfully
    failed: 3        # Processing failed
  }

  belongs_to :uploaded_by, class_name: "User"
  has_one_attached :file

  validates :filename, presence: true
  validates :file, presence: true, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(uploaded_by_id: user_id) }

  # Mark as processing and update timestamp
  def start_processing!
    update!(status: :processing, processed_rows: 0)
  end

  # Mark as completed with results
  def complete_processing!(success_count:, error_count:, results:)
    update!(
      status: :completed,
      success_count: success_count,
      error_count: error_count,
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
  def update_progress!(processed_rows:)
    update!(processed_rows: processed_rows)
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
end
