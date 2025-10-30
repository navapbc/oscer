# frozen_string_literal: true

class CreateExemptionApplicationForms < ActiveRecord::Migration[7.2]
  def change
    create_table :exemption_application_forms, id: :uuid do |t|
      # Base attributes
      t.uuid :user_id
      t.integer :status
      t.datetime :submitted_at

      # Additional form attributes
      t.string :exemption_type

      t.timestamps
    end
  end
end
