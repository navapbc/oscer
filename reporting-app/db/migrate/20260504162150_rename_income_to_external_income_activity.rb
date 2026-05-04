# frozen_string_literal: true

class RenameIncomeToExternalIncomeActivity < ActiveRecord::Migration[8.0]
  def change
    rename_index :incomes, :index_incomes_on_member_id, to: :index_external_income_activities_on_member_id
    rename_index :incomes, :index_incomes_on_period, to: :index_external_income_activities_on_period
    rename_index :incomes, :index_incomes_on_source, to: :index_external_income_activities_on_source

    rename_table :incomes, :external_income_activities
  end
end
