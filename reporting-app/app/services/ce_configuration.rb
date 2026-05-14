# frozen_string_literal: true

# Loads Community Engagement configuration from a template-owned base
# (config/ce_config_base.yml) deep-merged with an optional deployment-owned
# override (config/ce_config.yml — Copier-excluded for zero-conflict updates).
module CEConfiguration
  class ConfigurationError < StandardError; end

  module_function

  def load_and_merge(base_path, custom_path)
    base = safe_load_required(base_path)
    overrides = safe_load_optional(custom_path)
    base.deep_merge(overrides)
  end

  def transform_exemption_types(ce_data)
    raw = ce_data.fetch("exemption_types") do
      raise ConfigurationError, "Missing 'exemption_types' key in merged ce_data"
    end
    raw.map do |id, attrs|
      unless attrs.is_a?(Hash)
        raise ConfigurationError, "exemption_types.#{id}: expected Hash, got #{attrs.class}"
      end
      unless attrs.key?("enabled")
        raise ConfigurationError, "exemption_types.#{id}: missing required 'enabled' field"
      end
      attrs.symbolize_keys.merge(id: id.to_sym)
    end
  end

  def safe_load_required(path)
    unless File.exist?(path)
      raise ConfigurationError, "Required config file not found: #{path}"
    end
    parse_yaml(path)
  end

  def safe_load_optional(path)
    return {} unless File.exist?(path)
    parse_yaml(path)
  end

  def parse_yaml(path)
    raw = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
    unless raw.is_a?(Hash)
      raise ConfigurationError, "Expected a Hash at top level in #{path}, got #{raw.class}"
    end
    raw
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    raise ConfigurationError, "Invalid YAML in #{path}: #{e.message}"
  end
end
