# frozen_string_literal: true

class RemoveActivityReportCase < ActiveRecord::Migration[7.2]
  def change
    drop_table :activity_report_cases
  end
end
