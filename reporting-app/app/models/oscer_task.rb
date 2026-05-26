# frozen_string_literal: true

class OscerTask < Strata::Task
  # TODO: Figure out a better way to handle default due dates for tasks
  attribute :due_on, :date, default: -> { 7.days.from_now.to_date }

  def self.policy_class
    Strata::TaskPolicy
  end

  private

  def ensure_application_form
    if application_form.nil?
      application_forms = self.class.application_form_class.joins("LEFT JOIN strata_tasks ON #{self.class.application_form_class.table_name}.id = strata_tasks.application_form_id")
                                 .where("certification_case_id = ? AND strata_tasks.application_form_id IS NULL", case_id)
      self.application_form = application_forms.first
    end
  end
end
