class CreateCertificationOrigins < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_origins, id: :uuid do |t|
      t.uuid :certification_id, null: false
      t.string :source_type, null: false
      t.uuid :source_id

      t.timestamps
    end

    add_index :certification_origins, :certification_id, unique: true
    add_index :certification_origins, [ :source_type, :source_id ]
  end
end
