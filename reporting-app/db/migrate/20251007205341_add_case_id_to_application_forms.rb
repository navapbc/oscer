# frozen_string_literal: true

class AddCaseIdToApplicationForms < ActiveRecord::Migration[7.2]
  def change
    add_reference :activity_report_application_forms, :certification_case, foreign_key: true, type: :uuid
    add_reference :exemption_application_forms, :certification_case, foreign_key: true, type: :uuid
  end
end
