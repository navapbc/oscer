# frozen_string_literal: true

# This migration comes from flex (originally 20250826000000)
class AddCaseTypeToFlexTasks < ActiveRecord::Migration[7.2]
  def change
    add_column :flex_tasks, :case_type, :string
    add_index :flex_tasks, [ :case_id, :case_type ]
    remove_index :flex_tasks, :case_id
  end
end
