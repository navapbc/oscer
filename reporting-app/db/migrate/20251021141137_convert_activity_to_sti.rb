# frozen_string_literal: true

class ConvertActivityToSti < ActiveRecord::Migration[7.2]
  def up
    add_column :activities, :type, :string
    Activity.where(type: nil).update_all(type: 'WorkActivity')
  end
  def down
    remove_column :activities, :type
  end
end
