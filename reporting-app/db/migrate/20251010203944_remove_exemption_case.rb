# frozen_string_literal: true

class RemoveExemptionCase < ActiveRecord::Migration[7.2]
  def change
    drop_table :exemption_cases
  end
end
