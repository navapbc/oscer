# frozen_string_literal: true

class AddOriginToExternalActivities < ActiveRecord::Migration[8.0]
  def up
    add_column :external_hourly_activities, :origin_hash, :string
    add_column :external_income_activities, :origin_hash, :string

    add_index :external_hourly_activities, :origin_hash
    add_index :external_income_activities, :origin_hash
  end

  def down
    remove_column :external_hourly_activities, :origin_hash, :string
    remove_column :external_income_activities, :origin_hash, :string
  end
end
