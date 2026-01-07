# frozen_string_literal: true

class ExemptionTypeConfig
  class << self
    def all
      Rails.application.config.exemption_types
    end

    def enabled
      all.select { |_, v| v[:enabled] }
    end

    def enum_hash
      all.keys.index_with(&:to_s)
    end

    def valid_values
      all.keys.map(&:to_s)
    end

    def find(type)
      all[type.to_sym]
    end

    def question_for(type)
      config = find(type)
      return nil unless config

      I18n.t("exemption_types.#{type}.question", default: config[:question])
    end

    def explanation_for(type)
      config = find(type)
      return nil unless config

      I18n.t("exemption_types.#{type}.explanation", default: config[:explanation])
    end

    def yes_answer_for(type)
      config = find(type)
      return nil unless config

      I18n.t("exemption_types.#{type}.yes_answer", default: config[:yes_answer])
    end
  end
end
