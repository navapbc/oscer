# frozen_string_literal: true

class CreateStrataAuditLines < ActiveRecord::Migration[8.0]
  def change
    create_table :strata_audit_lines, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Required: what happened
      t.string :action, null: false

      # Optional polymorphic subject (the record this event is about)
      t.uuid   :subject_id
      t.string :subject_type

      # Optional polymorphic actor (who did it)
      t.uuid   :actor_id
      t.string :actor_type

      # Free-form jsonb payload for caller-supplied details
      t.jsonb :data, null: false, default: {}

      # Audit lines are immutable: created_at only, no updated_at
      t.datetime :created_at, null: false
    end

    # Composite index ordered by created_at DESC serves the dominant read
    # pattern: "most recent audit lines for this subject"
    add_index :strata_audit_lines, [ :subject_type, :subject_id, :created_at ],
              order: { created_at: :desc },
              name: "index_strata_audit_lines_on_subject_and_created_at"

    add_index :strata_audit_lines, [ :actor_type, :actor_id ],
              name: "index_strata_audit_lines_on_polymorphic_actor"

    add_index :strata_audit_lines, :created_at
  end
end
