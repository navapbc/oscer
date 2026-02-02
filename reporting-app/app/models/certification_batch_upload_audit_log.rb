# frozen_string_literal: true

class CertificationBatchUploadAuditLog < ApplicationRecord
  belongs_to :certification_batch_upload

  attribute :status, :string, default: "started"
  enum :status, {
    started: "started",      # Chunk processing began
    completed: "completed",  # Chunk succeeded (individual records may have failed validation)
    failed: "failed"         # Chunk job crashed (system error)
  }

  validates :chunk_number, presence: true, numericality: { greater_than: 0 }
  validates :succeeded_count, numericality: { greater_than_or_equal_to: 0 }
  validates :failed_count, numericality: { greater_than_or_equal_to: 0 }
end
