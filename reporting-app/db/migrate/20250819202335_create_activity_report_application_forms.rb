# frozen_string_literal: true

class CreateActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    create_table :activity_report_application_forms, id: :uuid do |t|
      t.timestamps
    end
  end
end
