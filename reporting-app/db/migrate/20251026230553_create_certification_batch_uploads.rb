# frozen_string_literal: true

class CreateCertificationBatchUploads < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_batch_uploads, id: :uuid do |t|
      t.string :filename, null: false
      t.integer :status, default: 0, null: false
      t.uuid :uploader_id, null: false
      t.integer :num_rows, default: 0
      t.integer :num_rows_processed, default: 0
      t.integer :num_rows_succeeded, default: 0
      t.integer :num_rows_errored, default: 0
      t.jsonb :results, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :certification_batch_uploads, :uploader_id
    add_index :certification_batch_uploads, :created_at
  end
end
