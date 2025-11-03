# frozen_string_literal: true

module ActivityHelper
  def build_activity_input_field(form, activity)
    if activity.is_a?(WorkActivity)
      form.text_field :hours, inputmode: "decimal", id: "activities-hours-input", label: t(".hours_label"), value: activity.try(:hours)
    elsif activity.is_a?(IncomeActivity)
      form.money_field :income, id: "activities-income-input", label: t(".income_label")
    else
      raise "Unknown activity type: #{activity.class.name}"
    end
  end
end