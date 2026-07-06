# frozen_string_literal: true

# Shared YAML load/parse/error plumbing for the config loaders that let a
# deployment override OSCER-shipped defaults via config/custom/*.yml
# (ExemptionTypesLoader, FeatureFlagsLoader, and future loaders).
#
# Loaders consume this by `extend ConfigLoading`, which turns these PUBLIC
# INSTANCE methods into PUBLIC singleton methods on the loader, so existing
# `Loader.safe_load_optional(path)` call sites keep working. Do NOT convert
# these to `module_function`: after `extend`, module_function methods land as
# PRIVATE singleton methods and the initializers' external
# `Loader.safe_load_optional(...)` calls would raise NoMethodError at boot.
#
# This module holds only the load/parse/error plumbing that is byte-identical
# across loaders. Each loader keeps its own (intentionally divergent) merge,
# validation, and transform logic.
module ConfigLoading
  class ConfigurationError < StandardError; end

  # Load an optional override file, treating a missing file as "no overrides".
  def safe_load_optional(path)
    return {} unless File.exist?(path)
    parse_yaml(path)
  end

  # Parse a YAML file with no Ruby object deserialization. Returns {} for an
  # empty/comment-only file (parses to nil); raises ConfigurationError on
  # malformed YAML, a disallowed Ruby tag, or a non-Hash top level.
  def parse_yaml(path)
    raw = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
    return {} if raw.nil?
    unless raw.is_a?(Hash)
      raise ConfigurationError, "Expected a Hash at top level in #{path}, got #{raw.class}"
    end
    raw
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    raise ConfigurationError, "Invalid YAML in #{path}: #{e.message}"
  end
end
