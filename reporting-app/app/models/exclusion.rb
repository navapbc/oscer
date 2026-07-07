# frozen_string_literal: true

# Utility class exposing the configured exclusions in priority order (highest
# durability first). Backs the background exclusion-determination flow, which
# evaluates exclusions from most to least durable. Configuration is loaded at
# boot into Rails.application.config.exclusion_types by
# config/initializers/exclusion_types.rb (see ExclusionTypesLoader).
#
# Exclusions are the mandatory federal minimum, so there is no enable/disable
# concept: every configured exclusion is always evaluated. This is the
# priority-ordering registry only; member-facing display is keyed by reason code
# elsewhere (MemberStatusService), not by this config.
class Exclusion
  class << self
    # All exclusions, sorted ascending by :priority (1 = highest durability).
    def all
      Rails.application.config.exclusion_types.sort_by { |t| t[:priority] }
    end

    # Exclusion ids in priority order (high durability -> low). This is the
    # order the determination flow evaluates, stopping at the first match.
    def priority_order
      all.map { |t| t[:id] }
    end

    # All exclusion ids as strings (for enum-style validation).
    def valid_values
      all.map { |t| t[:id].to_s }
    end

    def find(id)
      all.find { |t| t[:id] == id.to_sym }
    end
  end
end
