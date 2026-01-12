# frozen_string_literal: true

module ExemptionScreenerHelper
  # Generates array of step symbols dynamically based on enabled exemptions
  # Returns: [:start, :caregiver_child, :medical_condition, ..., :result]
  def exemption_screener_steps
    @exemption_screener_steps ||= [ :start ] + Exemption.enabled.map { |t| t[:id] } + [ :result ]
  end

  # Returns the display label for a given step symbol
  # All exemption type steps display "Exemption Questions"
  def exemption_screener_step_label(step)
    case step
    when :start, :result
      t("exemption_screener.steps.#{step}")
    else
      # All exemption type steps show the same label
      t("exemption_screener.steps.questions")
    end
  end

  # Determines the status of a step in the indicator
  # Returns: "complete", "current", or "incomplete"
  def exemption_screener_step_status(step_index, current_index)
    if step_index < current_index
      "complete"
    elsif step_index == current_index
      "current"
    else
      "incomplete"
    end
  end

  # Renders a back button with icon
  def back_button_with_icon(text, path, **options)
    link_to(path, **options) do
      svg_icon = content_tag(:svg, class: "usa-icon", aria: { hidden: true }, focusable: false, role: "img") do
        content_tag(:use, nil, "xlink:href" => "#{asset_path('@uswds/uswds/dist/img/sprite.svg')}#navigate_before")
      end
      concat svg_icon
      concat " #{text}"
    end
  end

  # Renders the appropriate back button for the exemption screener question page
  def exemption_screener_back_button(previous_exemption_type, certification_case)
    if previous_exemption_type.present?
      path = exemption_screener_question_path(
        exemption_type: previous_exemption_type,
        certification_case_id: certification_case.id
      )
      text = t("exemption_screener.show.buttons.back_to_previous")
    else
      path = exemption_screener_path(certification_case_id: certification_case.id)
      text = t("exemption_screener.show.buttons.back")
    end

    back_button_with_icon(text, path, class: "usa-button usa-button--outline")
  end
end
