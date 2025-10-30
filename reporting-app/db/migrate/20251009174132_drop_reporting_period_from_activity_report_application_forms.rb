# frozen_string_literal: true

class DropReportingPeriodFromActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    remove_column :activity_report_application_forms, :reporting_period, :date
  end
end
