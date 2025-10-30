# frozen_string_literal: true

class AddExemptionCaseTable < ActiveRecord::Migration[7.2]
  def change
    create_table :exemption_cases, id: :uuid do |t|
      t.uuid :application_form_id
      t.integer :status
      t.string :business_process_current_step
      t.jsonb :facts

      t.timestamps
    end
  end
end
