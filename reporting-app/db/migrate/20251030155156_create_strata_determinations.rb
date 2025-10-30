# frozen_string_literal: true

class CreateStrataDeterminations < ActiveRecord::Migration[7.2]
  def change
    create_table :strata_determinations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Polymorphic association to the subject (aggregate root) being determined
      t.uuid :subject_id, null: false
      t.string :subject_type, null: false

      # Decision metadata
      t.string :decision_method, null: false    # :automated, :staff_review, :attestation
      t.string :reason, null: false             # why the determination was made
      t.string :outcome, null: false            # result of the determination

      # Supporting data (e.g., rules engine output)
      t.jsonb :determination_data, null: false, default: {}

      # User who made the determination (nil if automated)
      t.uuid :determined_by_id

      # When the determination was made
      t.datetime :determined_at, null: false

      # Audit timestamp
      t.datetime :created_at, null: false
    end

    # Indexes for efficient querying
    add_index :strata_determinations, [ :subject_id, :subject_type ], name: "index_strata_determinations_on_polymorphic_subject"
    add_index :strata_determinations, :determined_by_id
    add_index :strata_determinations, :determined_at
    add_index :strata_determinations, :created_at
  end
end
