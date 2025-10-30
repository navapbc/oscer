# frozen_string_literal: true

class CreateCertifications < ActiveRecord::Migration[7.2]
  def change
    create_table :certifications, id: :uuid do |t|
      t.text :beneficiary_id
      t.text :case_number
      t.jsonb :certification_requirements
      t.jsonb :beneficiary_data

      t.timestamps
    end
    add_index :certifications, :beneficiary_id
    add_index :certifications, :case_number
  end
end
