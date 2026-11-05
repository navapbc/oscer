# frozen_string_literal: true

class CreateDeclaredEmergencies < ActiveRecord::Migration[8.0]
  def change
    create_table :declared_emergencies, id: :uuid do |t|
      t.string :fips_code, null: false
      t.string :designated_area
      t.string :declaration_title
      t.date :reported_to_cms_on
      t.date :period_start, null: false
      t.date :period_end
      t.string :origin_id
      t.string :origin_hash
      t.jsonb :origin_raw
      t.date :deleted_on
      t.timestamps

      t.index :fips_code
      # Partial unique: a superseded (soft-deleted) row must not block its successor.
      t.index :origin_id, unique: true, where: "deleted_on IS NULL"
      t.index :origin_hash, unique: true, where: "deleted_on IS NULL"
      t.index [ :period_start, :period_end ], name: "index_declared_emergencies_on_period"
    end
  end
end
