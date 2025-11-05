# frozen_string_literal: true

class CreateCertificationBatchUploads < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_batch_uploads, id: :uuid do |t|
      t.string :filename, null: false
      t.integer :status, default: 0, null: false
      t.uuid :uploaded_by_id, null: false
      t.integer :total_rows, default: 0
      t.integer :processed_rows, default: 0
      t.integer :success_count, default: 0
      t.integer :error_count, default: 0
      t.jsonb :results, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :certification_batch_uploads, :uploaded_by_id
    add_index :certification_batch_uploads, :status
    add_index :certification_batch_uploads, :created_at
  end
end
