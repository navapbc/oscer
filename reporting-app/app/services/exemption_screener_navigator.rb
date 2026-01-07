# frozen_string_literal: true

# ExemptionScreenerNavigator
#
# Service object that handles navigation logic for the exemption screener.
# Determines current question, next/previous locations, and validates navigation state.
#
# Usage:
#   navigator = ExemptionScreenerNavigator.new(config, "medical_condition", 0)
#   navigator.valid? # => true
#   navigator.current_question # => {question: "...", description: "...", yes_answer: "..."}
#   navigator.next_location(answer: "yes") # => [:may_qualify, "medical_condition"]
#   navigator.next_location(answer: "no") # => [:question, "medical_condition", 1]
#   navigator.previous_location # => nil (first question)
#
class ExemptionScreenerNavigator
  attr_reader :config, :exemption_type, :question_index

  def initialize(config, exemption_type, question_index)
    @config = config
    @exemption_type = exemption_type
    @question_index = question_index
  end

  # Returns the current question hash from config
  # Returns nil if invalid
  def current_question
    return nil unless valid?

    questions = config.questions_for(exemption_type)
    questions[question_index]
  end

  # Returns the next location based on the user's answer
  # Returns [:may_qualify, exemption_type] if answer is "yes"
  # Returns [:question, next_exemption_type, next_question_index] if answer is "no" and more questions
  # Returns [:complete] if answer is "no" and no more questions
  def next_location(answer:)
    if answer == "yes"
      [ :may_qualify, exemption_type ]
    else
      next_exemption_type, next_question_index = next_question_params

      if next_exemption_type.present?
        [ :question, next_exemption_type, next_question_index ]
      else
        [ :complete ]
      end
    end
  end

  # Returns the previous location
  # Returns [exemption_type, question_index] if there's a previous question
  # Returns nil if this is the first question
  def previous_location
    previous_exemption_type, previous_question_index = previous_question_params
    return nil unless previous_exemption_type.present?

    [ previous_exemption_type, previous_question_index ]
  end

  # Returns true if the current exemption_type and question_index are valid
  def valid?
    config.valid_question?(exemption_type, question_index)
  end

  private

  def next_question_params
    config.next_question(exemption_type, question_index)
  end

  def previous_question_params
    config.previous_question(exemption_type, question_index)
  end
end
