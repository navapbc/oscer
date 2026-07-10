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
  # Data Source Hierarchy spec. The ruled exclusions (is_pregnant,
  # is_american_indian_or_alaska_native, is_veteran_with_disability) use ids that
  # match their Rules::ExclusionRuleset fact names, so the determination flow
  # resolves an exclusion's priority directly by fact via Exclusion.find, with no
  # separate id<->fact bridge. The rest are declarative until their rules land.
  #
  # Priorities are spaced by 10 so a deployment can re-rank one exclusion by
  # dropping it into the gap between two others (e.g. priority 55 to sit
  # between 50 and 60) without renumbering the rest.
  DEFAULTS = {
    "is_american_indian_or_alaska_native" => { "priority" => 10 },
    "former_foster_care" => { "priority" => 20 },
    "is_veteran_with_disability" => { "priority" => 30 },
    "medically_frail" => { "priority" => 40 },
    "caretaker" => { "priority" => 50 },
    "tanf_snap_work" => { "priority" => 60 },
    "drug_treatment" => { "priority" => 70 },
    "is_pregnant" => { "priority" => 80 },
    "inmate" => { "priority" => 90 }
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
