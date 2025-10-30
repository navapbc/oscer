# frozen_string_literal: true

class AddCertificationToActivityReportApplicationForm < ActiveRecord::Migration[7.2]
  def change
    add_reference :activity_report_application_forms, :certification, null: true, foreign_key: true, type: :uuid
  end
end
