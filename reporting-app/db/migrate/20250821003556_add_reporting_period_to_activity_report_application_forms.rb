# frozen_string_literal: true

class AddReportingPeriodToActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_application_forms, :reporting_period, :date
  end
end
