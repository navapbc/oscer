# frozen_string_literal: true

require_relative "config_loading"

# Loads exclusion-type configuration by deep-merging an optional deployment
# override (config/custom/exclusion_types.yml, the deployment-owned override
# surface) over the mandatory federal-minimum exclusions declared in DEFAULTS
# below.
#
# Exclusions are the federal minimum set of conditions that remove a member from
# the community-engagement requirement; a deployment cannot disable one, so
# entries carry no `enabled` flag. The only configurable dimension is `priority`
# (Integer, 1 = highest durability), which lets a deployment re-rank the order in
# which exclusions are evaluated. The default ranking is OSCER-owned (updated by
# Nava as CMS regulations evolve).
#
# Mirrors ExemptionTypesLoader; the YAML load/parse/error plumbing lives in the
# shared ConfigLoading module (extend below). This loader keeps only its
# deep-merge + transform logic, whose validation requires a distinct integer
# `priority` per entry.
module ExclusionTypesLoader
  extend ConfigLoading

  # Alias keeps ExclusionTypesLoader::ConfigurationError valid for existing
  # rescues/specs; unqualified `raise ConfigurationError` in transform resolves
  # to it via lexical scope, so no raise site changes.
  ConfigurationError = ConfigLoading::ConfigurationError

  # Default exclusion priority order (high durability -> low), per the
  # Data Source Hierarchy spec. Only american_indian_alaska_native,
  # veteran_disability, and pregnant have rules in Rules::ExclusionRuleset
  # today; the rest are declarative until their rules land.
  DEFAULTS = {
    "american_indian_alaska_native" => { "priority" => 1 },
    "former_foster_care" => { "priority" => 2 },
    "veteran_disability" => { "priority" => 3 },
    "medically_frail" => { "priority" => 4 },
    "caretaker" => { "priority" => 5 },
    "tanf_snap_work" => { "priority" => 6 },
    "drug_treatment" => { "priority" => 7 },
    "pregnant" => { "priority" => 8 },
    "inmate" => { "priority" => 9 }
  }.freeze

  module_function

  def merge_with_defaults(overrides)
    DEFAULTS.deep_merge(overrides)
  end

  def transform(merged)
    entries = merged.map do |id, attrs|
      unless attrs.is_a?(Hash)
        raise ConfigurationError, "exclusion_types.#{id}: expected Hash, got #{attrs.class}"
      end
      unless attrs.key?("priority")
        raise ConfigurationError, "exclusion_types.#{id}: missing required 'priority' field"
      end
      unless attrs["priority"].is_a?(Integer)
        raise ConfigurationError, "exclusion_types.#{id}: 'priority' must be an Integer"
      end
      attrs.symbolize_keys.merge(id: id.to_sym)
    end

    # Priority is a strict ordering: two exclusions sharing a priority would make
    # evaluation order depend on an unstable sort. Reject duplicates at boot
    # rather than silently pick a winner.
    duplicates = entries.map { |e| e[:priority] }.tally.select { |_priority, count| count > 1 }.keys.sort
    unless duplicates.empty?
      raise ConfigurationError, "exclusion_types: duplicate priority values #{duplicates}; each exclusion must have a distinct priority"
    end

    entries
  end
end
