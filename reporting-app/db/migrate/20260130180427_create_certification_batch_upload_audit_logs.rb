# frozen_string_literal: true

# Migration to support batch upload v2 chunk-level audit logging
# Tracks processing status for each 1,000-record chunk:
# - status: started/completed/failed (chunk-level outcome)
# - succeeded_count/failed_count: record-level results (when completed)
# - timestamps: created_at = start, updated_at = completion (for duration calculation)
class CreateCertificationBatchUploadAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_batch_upload_audit_logs, id: :uuid do |t|
      t.references :certification_batch_upload, type: :uuid, foreign_key: true, null: false, index: true
      t.integer :chunk_number, null: false
      t.string :status, null: false, default: "started"
      t.integer :succeeded_count, default: 0
      t.integer :failed_count, default: 0
      t.timestamps

      t.index [ :certification_batch_upload_id, :chunk_number ],
        name: "idx_audit_logs_on_upload_chunk"
      t.index :status, name: "idx_audit_logs_on_status"
    end
  end
end
