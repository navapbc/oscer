# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :activities, id: :uuid do |t|
      t.references :activity_report_application_form, null: false, foreign_key: true, type: :uuid
      t.date :month
      t.decimal :hours
      t.string :name

      t.timestamps
    end
  end
end
