# frozen_string_literal: true

class AddUniqueIndicesOnApplicationForms < ActiveRecord::Migration[7.2]
  def change
    remove_index :activity_report_application_forms, :certification_case_id
    add_index :activity_report_application_forms, :certification_case_id, unique: true

    remove_index :exemption_application_forms, :certification_case_id
    add_index :exemption_application_forms, :certification_case_id, unique: true


    remove_column :activity_report_application_forms, :certification_id
    remove_column :exemption_application_forms, :certification_id
  end
end
