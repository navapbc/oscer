# frozen_string_literal: true

class CreateInformationRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :information_requests, id: :uuid do |t|
      t.string :type, null: false
      t.uuid :application_form_id, null: false
      t.string :application_form_type, null: false
      t.text :staff_comment, null: false
      t.text :member_comment
      t.date :due_date, null: false

      t.timestamps
    end
  end
end
