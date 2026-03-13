# frozen_string_literal: true

class AddEvidenceSourceToActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :activities, :evidence_source, :string
  end
end
