# frozen_string_literal: true

class ChangeFlexTasksToStrataTasks < ActiveRecord::Migration[7.2]
  def change
    rename_table :flex_tasks, :strata_tasks
  end
end
