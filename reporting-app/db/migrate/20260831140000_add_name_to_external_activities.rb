# frozen_string_literal: true

class AddNameToExternalActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :external_hourly_activities, :name, :string
    add_column :external_income_activities, :name, :string
  end
end
