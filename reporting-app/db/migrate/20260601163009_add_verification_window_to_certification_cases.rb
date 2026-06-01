# frozen_string_literal: true

class AddVerificationWindowToCertificationCases < ActiveRecord::Migration[8.0]
  def change
    add_column :certification_cases, :verification_window_start_date, :date, comment: "The start date for the time a member is given to resolve a negative determination on their CE certification"
    add_column :certification_cases, :verification_window_end_date, :date, comment: "The end date for the time a member is given to resolve a negative determination on their CE certification"
  end
end
