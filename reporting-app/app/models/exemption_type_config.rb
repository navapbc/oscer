# frozen_string_literal: true

class ExemptionTypeConfig
  class << self
    def all
      Rails.application.config.exemption_types
    end

    def enabled
      all.select { |t| t[:enabled] }
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

    def title_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.title", default: exemption_type[:title])
    end

    def description_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.description", default: exemption_type[:description])
    end

    def supporting_documents_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.supporting_documents", default: exemption_type[:supporting_documents])
    end

    def question_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.question", default: exemption_type[:question])
    end

    def explanation_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.explanation", default: exemption_type[:explanation])
    end

    def yes_answer_for(type)
      exemption_type = find(type)
      return nil unless exemption_type

      I18n.t("exemption_types.#{exemption_type[:id]}.yes_answer", default: exemption_type[:yes_answer])
    end
  end
end
