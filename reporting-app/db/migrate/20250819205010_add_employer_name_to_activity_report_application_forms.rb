# frozen_string_literal: true

class AddEmployerNameToActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_application_forms, :employer_name, :string
  end
end
