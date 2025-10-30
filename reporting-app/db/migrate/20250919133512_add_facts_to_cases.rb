# frozen_string_literal: true

class AddFactsToCases < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_cases, :facts, :jsonb, default: {}
  end
end
