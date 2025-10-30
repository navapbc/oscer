# frozen_string_literal: true

class CreateActivityReportCases < ActiveRecord::Migration[7.2]
  def change
    create_table :activity_report_cases, id: :uuid do |t|
      t.uuid :application_form_id
      t.integer :status
      t.string :business_process_current_step

      t.timestamps
    end
  end
end
