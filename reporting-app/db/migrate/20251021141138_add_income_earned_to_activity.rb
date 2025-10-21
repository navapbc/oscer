class AddIncomeEarnedToActivity < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :earned_income, :integer
  end
end
