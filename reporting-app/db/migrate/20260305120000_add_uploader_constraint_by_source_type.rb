# frozen_string_literal: true

# Enforces that UI uploads always have an uploader, while API and storage_event
# uploads are allowed to have a nil uploader_id.
class AddUploaderConstraintBySourceType < ActiveRecord::Migration[7.2]
  def up
    # Safety backfill: ensure no existing UI rows violate the constraint
    execute <<~SQL
      UPDATE certification_batch_uploads
      SET source_type = 'api'
      WHERE source_type = 'ui' AND uploader_id IS NULL
    SQL

    execute <<~SQL
      ALTER TABLE certification_batch_uploads
      ADD CONSTRAINT require_uploader_for_ui_uploads
      CHECK (source_type != 'ui' OR uploader_id IS NOT NULL)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE certification_batch_uploads
      DROP CONSTRAINT require_uploader_for_ui_uploads
    SQL
  end
end
