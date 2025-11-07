# frozen_string_literal: true

class AddCategoryToActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :category, :string
    add_index :activities, :category
  end
end
