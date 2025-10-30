# frozen_string_literal: true

class AddCertificateFkToExemptions < ActiveRecord::Migration[7.2]
  def change
    add_reference :exemption_application_forms, :certification, null: true, foreign_key: true, type: :uuid, index: true
  end
end
