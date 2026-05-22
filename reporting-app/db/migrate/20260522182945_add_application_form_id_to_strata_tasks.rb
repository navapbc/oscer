# frozen_string_literal: true

class AddApplicationFormIdToStrataTasks < ActiveRecord::Migration[8.0]
  def up
    add_column :strata_tasks, :application_form_id, :uuid

    [ ReviewExemptionClaimTask, ReviewActivityReportTask ].each do |klass|
      klass.find_each do |task|
        application_form = task.class.application_form_class.find_by(certification_case_id: task.case_id)
        task.update_column(:application_form_id, application_form&.id)
      end
    end
  end

  def down
    remove_column :strata_tasks, :application_form_id
  end
end
