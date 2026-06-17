# frozen_string_literal: true

class CreateDenialResponseApplicationForms < ActiveRecord::Migration[8.0]
  def change
    create_table :denial_response_application_forms, id: :uuid do |t|
      t.uuid :user_id
      t.integer :status
      t.datetime :submitted_at
      t.uuid :certification_case_id
      t.text :comment

      t.timestamps
    end

    add_index :denial_response_application_forms, :certification_case_id
  end
end
