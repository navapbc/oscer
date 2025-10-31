# frozen_string_literal: true

class UpdateDeterminationReasons < ActiveRecord::Migration[7.2]
  def up
    # Add the new reasons column as an array of strings
    add_column :strata_determinations, :reasons, :string, array: true, default: [], null: false

    # Copy existing reason values into reasons array
    execute <<~SQL
      UPDATE strata_determinations
      SET reasons = ARRAY[reason]
      WHERE reason IS NOT NULL AND reason != ''
    SQL

    # Remove the old reason column
    remove_column :strata_determinations, :reason
  end

  def down
    # Add back the old reason column
    add_column :strata_determinations, :reason, :string, null: false, default: ""

    # Copy first reason from array back to reason column
    execute <<~SQL
      UPDATE strata_determinations
      SET reason = reasons[1]
      WHERE array_length(reasons, 1) >= 1
    SQL

    # Remove the reasons column
    remove_column :strata_determinations, :reasons
  end
end
