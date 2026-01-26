# frozen_string_literal: true

# Migration to support batch upload v2 with direct cloud storage
# - storage_key: S3/cloud object key for v2 uploads (null for legacy Active Storage)
# - source_type: How file was uploaded (ui/api/ftp/storage_event), defaults to "ui"
class AddStorageKeyAndSourceTypeToCertificationBatchUploads < ActiveRecord::Migration[7.2]
  def change
    add_column :certification_batch_uploads, :storage_key, :string
    add_column :certification_batch_uploads, :source_type, :string, default: "ui"

    add_index :certification_batch_uploads, :source_type
  end
end
