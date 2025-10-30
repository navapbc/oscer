# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string "uid", null: false
      t.string "provider", null: false
      t.string "email", default: "", null: false
      t.integer "mfa_preference"
      t.index [ "uid" ], name: "index_users_on_uid", unique: true

      t.timestamps
    end
  end
end
