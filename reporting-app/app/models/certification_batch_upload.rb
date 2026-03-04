# frozen_string_literal: true

class CertificationBatchUpload < ApplicationRecord
  # Status workflow for batch upload processing
  attribute :status, :string, default: :pending
  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

  # Source type indicates how the file was uploaded
  enum :source_type, { ui: "ui", api: "api", storage_event: "storage_event" }

  attribute :num_rows, :integer, default: 0
  attribute :num_rows_processed, :integer, default: 0
  attribute :num_rows_succeeded, :integer, default: 0
  attribute :num_rows_errored, :integer, default: 0
  attribute :results, :jsonb, default: {}

  belongs_to :uploader, class_name: "User", optional: true
  has_one_attached :file
  has_many :audit_logs,
           class_name: "CertificationBatchUploadAuditLog",
           strict_loading: true,
           dependent: :destroy
  has_many :upload_errors,
           class_name: "CertificationBatchUploadError",
           strict_loading: true,
           dependent: :destroy

  validates :filename, presence: true
  validates :file, attached: true, on: :create
  validates :file,
            content_type: [
              "text/csv",
              "text/plain",
              "application/vnd.ms-excel",
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            ],
            size: { less_than: 100.megabytes, message: "must be less than 100MB" },
            on: :create

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

  # Check if all chunks have reported in and transition to a terminal state.
  # Called by both successful chunks and the discard_on block for failed chunks.
  #
  # Uses SQL-level locking and update_columns to avoid strict_loading violations
  # that occur when with_lock reloads the record without eager-loaded ActiveStorage.
  #
  # Status determination uses audit log status (not just row counts):
  # - Any chunk completed (ran successfully) → completed (with errors if applicable)
  # - All chunks failed (system errors) → failed
  def check_completion!
    # NOTE: Avoid `return` inside transaction blocks — Rails 7.2 treats non-local
    # returns as rollbacks and raises ActiveRecord::Rollback in the ensure block.
    # Use if/else flow control instead.
    self.class.transaction do
      # Lock the row and read attributes without loading a full AR object
      row = self.class.unscoped.where(id: id).lock(true).pick(
        :num_rows_processed, :num_rows, :status,
        :num_rows_succeeded, :num_rows_errored
      )

      if row
        num_processed, total, current_status, succeeded, errored = row

        if num_processed >= total && !current_status.in?(%w[completed failed])
          any_chunk_completed = CertificationBatchUploadAuditLog.where(
            certification_batch_upload_id: id,
            status: :completed
          ).exists?

          if any_chunk_completed
            update_columns(
              status: :completed,
              num_rows_succeeded: succeeded,
              num_rows_errored: errored,
              results: {},
              processed_at: Time.current,
              updated_at: Time.current
            )
          else
            update_columns(
              status: :failed,
              results: { error: "All chunks failed to process" },
              processed_at: Time.current,
              updated_at: Time.current
            )
          end
        end
      end
    end
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

  # Get the storage key for streaming the CSV file
  # @return [String, nil] S3 key for the uploaded file, or nil if no file attached
  def storage_key
    file.blob.key if file.attached?
  end
end
