# frozen_string_literal: true

# ExemptionScreenerNavigator
#
# Service object that handles navigation logic for the exemption screener.
# Determines current question, next/previous locations, and validates navigation state.
#
# Usage:
#   navigator = ExemptionScreenerNavigator.new("medical_condition")
#   navigator.valid? # => true
#   navigator.current_question # => {"question" => "...", "explanation" => "...", "yes_answer" => "..."}
#   navigator.next_location(answer: "yes") # => [:may_qualify, "medical_condition"]
#   navigator.next_location(answer: "no") # => [:question, "incarceration"]
#   navigator.previous_location # => "care_giver_child" (or nil if first)
#
class ExemptionScreenerNavigator
  attr_reader :exemption_type

  def initialize(exemption_type)
    @exemption_type = exemption_type
  end

  # Returns the current question hash from config
  # Returns nil if invalid
  def current_question
    return nil unless valid?

    Exemption.question_data_for(exemption_type)
  end

  # Returns the next location based on the user's answer
  # Returns [:may_qualify, exemption_type] if answer is "yes"
  # Returns [:question, next_exemption_type] if answer is "no" and more types exist
  # Returns [:complete] if answer is "no" and no more types
  def next_location(answer:)
    if answer == "yes"
      [ :may_qualify, exemption_type ]
    else
      next_type = Exemption.next_type(exemption_type)

      if next_type.present?
        [ :question, next_type ]
      else
        [ :complete ]
      end
    end
  end

  # Returns the previous exemption type
  # Returns the previous exemption type symbol if there is one
  # Returns nil if this is the first type
  def previous_location
    Exemption.previous_type(exemption_type)
  end

  # Returns true if the current exemption_type is valid
  def valid?
    Exemption.valid_type?(exemption_type)
  end
end
