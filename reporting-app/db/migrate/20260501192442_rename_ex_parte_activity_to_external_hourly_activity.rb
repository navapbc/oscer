# frozen_string_literal: true

class RenameExParteActivityToExternalHourlyActivity < ActiveRecord::Migration[8.0]
  def change
    rename_index :ex_parte_activities, :index_ex_parte_activities_on_member_id, :index_external_hourly_activities_on_member_id
    rename_index :ex_parte_activities, :index_ex_parte_activities_on_period, :index_external_hourly_activities_on_period
    rename_index :ex_parte_activities, :index_ex_parte_activities_on_source, :index_external_hourly_activities_on_source

    rename_table :ex_parte_activities, :external_hourly_activities
  end
end
