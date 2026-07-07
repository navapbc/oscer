# frozen_string_literal: true

# Registry over the external-exception configuration loaded by
# ExternalExceptionsLoader and assigned to Rails.application.config.external_exceptions
# on boot.
#
# These are the optional short-term hardship exceptions evaluated by the
# external exception check (ExceptionDeterminationService). The service consults
# .enabled? to gate each check, so a deployment can disable any optional
# exception via config/custom/external_exceptions.yml.
#
# Named ExternalException (not Exception) because Exception is a reserved Ruby
# core class. This mirrors Exemption but is intentionally leaner: external
# exceptions have no member- or staff-facing UI, so there are no I18n metadata
# accessors.
class ExternalException
  class << self
    def all
      Rails.application.config.external_exceptions
    end

    def enabled
      all.select { |t| t[:enabled] }
    end

    def ids
      all.map { |t| t[:id] }
    end

    def find(id)
      all.find { |t| t[:id] == id.to_sym }
    end

    # True when +id+ is a known external exception that is currently enabled.
    # ExceptionDeterminationService calls this before running each check.
    def enabled?(id)
      enabled.any? { |t| t[:id] == id.to_sym }
    end

    # True when +id+ is a known external exception, regardless of enabled state.
    def valid_type?(id)
      all.any? { |t| t[:id] == id.to_sym }
    end
  end
end
