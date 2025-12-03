class AddUserRoleAttributes < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :roles, :string, array: true, null: false, default: []
    add_column :users, :program, :string, null: false, default: "Medicaid"
    add_column :users, :region, :string, null: false, default: "Northwest"

    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
  end
end
