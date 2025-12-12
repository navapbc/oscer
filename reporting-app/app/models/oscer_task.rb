# frozen_string_literal: true

class OscerTask < Strata::Task
  # TODO: Figure out a better way to handle default due dates for tasks
  attribute :due_on, :date, default: -> { 7.days.from_now.to_date }

  def self.policy_class
    TaskPolicy
  end
end
