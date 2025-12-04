# frozen_string_literal: true

class AddUserRoleAttributes < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :role, :string
    add_column :users, :region, :string
  end
end
