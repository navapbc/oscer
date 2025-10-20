# frozen_string_literal: true

class ReviewActivityReportTask < Strata::Task
  # TODO: move :on_hold to Strata::Task
  enum :status, { pending: 0, completed: 1, on_hold: 2 }

  # TODO: Figure out a better way to handle default due dates for tasks
  attribute :due_on, :date, default: -> { 7.days.from_now.to_date }

  def self.application_form_class
    ActivityReportApplicationForm
  end
end
