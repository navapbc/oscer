# frozen_string_literal: true

class AddMinutesToActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_application_forms, :minutes, :integer
  end
end
