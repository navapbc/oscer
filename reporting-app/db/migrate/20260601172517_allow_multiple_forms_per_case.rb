# frozen_string_literal: true

class AllowMultipleFormsPerCase < ActiveRecord::Migration[8.0]
  def change
    remove_index :activity_report_application_forms, :certification_case_id, unique: true
    add_index :activity_report_application_forms, :certification_case_id
    remove_index :exemption_application_forms, :certification_case_id, unique: true
    add_index :exemption_application_forms, :certification_case_id
  end
end
