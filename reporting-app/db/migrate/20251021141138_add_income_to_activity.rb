# frozen_string_literal: true

class AddIncomeToActivity < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :income, :integer
  end
end
