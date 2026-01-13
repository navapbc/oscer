# frozen_string_literal: true

class Exemption
  class << self
    def all
      Rails.application.config.exemption_types
    end

    def enabled
      all.select { |t| t[:enabled] }
    end

    def types
      valid_values
    end

    def enum_hash
      all.map { |t| t[:id] }.index_with(&:to_s)
    end

    def valid_values
      all.map { |t| t[:id] }.map(&:to_s)
    end

    def find(type)
      all.find { |t| t[:id] == type.to_sym }
    end

    ATTRIBUTES = %i[title description supporting_documents question explanation yes_answer].freeze

    # Dynamically define methods that fetch I18n translations for exemption types
    # Each method follows the pattern: attribute_for(type)
    ATTRIBUTES.each do |attribute|
      define_method("#{attribute}_for") do |type|
        exemption_type = find(type)
        return nil unless exemption_type

        I18n.t("exemption_types.#{exemption_type[:id]}.#{attribute}")
      end
    end

    # Returns a hash with the question data for the given type
    # Used by the screener to display the question
    def question_data_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      {
        "question" => question_for(type),
        "explanation" => explanation_for(type),
        "yes_answer" => yes_answer_for(type)
      }
    end

    # Returns the first enabled exemption type
    def first_type
      enabled.first&.dig(:id)
    end

    # Returns the next enabled exemption type after the given type
    # Returns nil if this is the last type
    def next_type(type)
      enabled_types = enabled.map { |t| t[:id] }
      current_index = enabled_types.index(type.to_sym)
      return nil unless current_index

      enabled_types[current_index + 1]
    end

    # Returns the previous enabled exemption type before the given type
    # Returns nil if this is the first type
    def previous_type(type)
      enabled_types = enabled.map { |t| t[:id] }
      current_index = enabled_types.index(type.to_sym)
      return nil unless current_index && current_index > 0

      enabled_types[current_index - 1]
    end

    # Returns true if the given type is a valid enabled exemption type
    def valid_type?(type)
      enabled.any? { |t| t[:id] == type.to_sym }
    end
  end
end
