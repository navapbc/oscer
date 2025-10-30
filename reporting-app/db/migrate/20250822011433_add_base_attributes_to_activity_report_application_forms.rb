# frozen_string_literal: true

class AddBaseAttributesToActivityReportApplicationForms < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_report_application_forms, :user_id, :uuid
    add_column :activity_report_application_forms, :status, :integer
    add_column :activity_report_application_forms, :submitted_at, :datetime
  end
end
