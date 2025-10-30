# frozen_string_literal: true

class AddCaseTypeValuesToFlexTasks < ActiveRecord::Migration[7.2]
  def change
    # Strata::Task.where(case_type: nil).update_all(case_type: "ActivityReportCase")
  end
end
