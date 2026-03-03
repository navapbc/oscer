# frozen_string_literal: true

# Migration to remove storage_key column from certification_batch_uploads
# As part of Active Storage adoption (Story 14), all uploads now use Active Storage blobs.
# The storage_key column was used by the custom presigned URL approach (Stories 0-8).
# After this migration, blob.key is used instead of storage_key for streaming.
# Safe to remove: V2 is pre-production with no data using storage_key.
class RemoveStorageKeyFromCertificationBatchUploads < ActiveRecord::Migration[7.2]
  def change
    remove_column :certification_batch_uploads, :storage_key, :string
  end
end
