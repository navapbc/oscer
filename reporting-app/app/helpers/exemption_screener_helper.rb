# frozen_string_literal: true

module ExemptionScreenerHelper
  # Generates array of step symbols dynamically based on enabled exemptions
  # Returns: [:start, :caregiver_child, :medical_condition, ..., :result]
  def exemption_screener_steps
    @exemption_screener_steps ||= [ :start ] + Exemption.enabled.map { |t| t[:id] } + [ :result ]
  end

  # Returns the display label for a given step symbol
  def exemption_screener_step_label(step)
    case step
    when :start, :result
      t("exemption_screener.steps.#{step}")
    else
      Exemption.title_for(step)
    end
  end
end
