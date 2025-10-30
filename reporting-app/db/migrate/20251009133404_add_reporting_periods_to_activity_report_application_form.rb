# frozen_string_literal: true

class AddReportingPeriodsToActivityReportApplicationForm < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_application_forms, :reporting_periods, :jsonb
  end
end
