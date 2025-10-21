class AddIncomeEarnedToActivity < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :income_earned, :integer
  end
end
