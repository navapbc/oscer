# frozen_string_literal: true

class RemoveFieldsFromActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    remove_column :activity_report_application_forms, :employer_name, :string
    remove_column :activity_report_application_forms, :minutes, :integer
  end
end
