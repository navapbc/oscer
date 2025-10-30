# frozen_string_literal: true

class CreateCertificationCases < ActiveRecord::Migration[7.2]
  def change
    create_table :certification_cases, id: :uuid do |t|
      t.references :certification, null: false, foreign_key: true, type: :uuid
      t.integer :status
      t.string :business_process_current_step
      t.jsonb :facts

      t.timestamps
    end
  end
end
