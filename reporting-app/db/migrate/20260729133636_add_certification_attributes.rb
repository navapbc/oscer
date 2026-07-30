# frozen_string_literal: true

class AddCertificationAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :certifications, :application_date, :date
    add_column :certifications, :household_data, :jsonb
  end
end
