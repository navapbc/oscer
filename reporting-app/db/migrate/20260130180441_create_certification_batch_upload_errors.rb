# frozen_string_literal: true

# Migration to support batch upload v2 error tracking
# Stores individual failed CSV records for analysis and retry:
# - row_number: Line number in original CSV file (user-facing reference)
# - error_code: Structured code for categorization (e.g., VAL_001)
# - error_message: Human-readable description
# - row_data: Full CSV row as JSONB for retry attempts
class CreateCertificationBatchUploadErrors < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_batch_upload_errors, id: :uuid do |t|
      t.references :certification_batch_upload, type: :uuid, foreign_key: true, null: false, index: true
      t.integer :row_number, null: false
      t.string :error_code, null: false
      t.string :error_message, null: false
      t.jsonb :row_data
      t.timestamps

      t.index [ :certification_batch_upload_id, :error_code ],
        name: "idx_upload_errors_on_upload_code"
    end
  end
end
