# frozen_string_literal: true

# Maps IdP groups to OSCER roles for Staff SSO
#
# Reads configuration from config/sso_role_mapping.yml to determine
# how IdP group memberships translate to OSCER application roles.
#
# Usage:
#   mapper = RoleMapper.new
#   role = mapper.map_groups_to_role(["OSCER-Admin", "Other-Group"])
#   # => "admin"
#
# Configuration supports:
#   - Multiple IdP groups mapping to the same OSCER role
#   - Case-insensitive group matching
#   - Configurable behavior when no groups match (deny or assign default)
#
class RoleMapper
  class ConfigurationError < StandardError; end

  DEFAULT_CONFIG_PATH = Rails.root.join("config/sso_role_mapping.yml")

  # @param config [Hash, nil] Configuration hash (for testing). If nil, loads from config_path.
  # @param config_path [Pathname, String] Path to YAML config file (default: config/sso_role_mapping.yml)
  def initialize(config: nil, config_path: DEFAULT_CONFIG_PATH)
    @config = config&.deep_symbolize_keys || load_config(config_path)
    validate_config!
    @normalized_mappings = build_normalized_mappings
  end

  # Map IdP groups to an OSCER role
  # Returns the first matching role based on configuration order
  # @param groups [Array<String>] IdP group names from token claims
  # @return [String, nil] OSCER role name or nil if no match
  def map_groups_to_role(groups)
    return nil if groups.blank?

    normalized_groups = groups.map(&:downcase)

    @normalized_mappings.each do |role, idp_groups|
      # Return role if any IdP group matches
      return role.to_s if (idp_groups & normalized_groups).any?
    end

    nil
  end

  # Check if access should be denied when no role matches
  # @return [Boolean]
  def deny_if_no_match?
    @config[:no_match_behavior] == "deny"
  end

  # Get the default role to assign when no groups match
  # Only used when no_match_behavior is "assign_default"
  # @return [String, nil]
  def default_role
    @config[:default_role]
  end

  private

  def load_config(config_path)
    unless File.exist?(config_path)
      raise ConfigurationError, "Role mapping configuration not found: #{config_path}"
    end

    # Use safe_load to prevent arbitrary object deserialization
    yaml_content = File.read(config_path)
    YAML.safe_load(yaml_content, permitted_classes: [], permitted_symbols: [], aliases: false)
        .deep_symbolize_keys
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    raise ConfigurationError, "Invalid YAML in role mapping configuration: #{e.message}"
  end

  def validate_config!
    if @config[:role_mappings].nil?
      raise ConfigurationError, "role_mappings key is required"
    end

    unless @config[:role_mappings].is_a?(Hash)
      raise ConfigurationError, "role_mappings must be a hash"
    end

    if @config[:role_mappings].empty?
      raise ConfigurationError, "role_mappings cannot be empty"
    end

    @config[:role_mappings].each do |role, groups|
      unless groups.is_a?(Array)
        raise ConfigurationError, "role_mappings.#{role} must be an array of group names"
      end
    end

    unless %w[deny assign_default].include?(@config[:no_match_behavior])
      raise ConfigurationError, "no_match_behavior must be 'deny' or 'assign_default'"
    end
  end

  def build_normalized_mappings
    @config[:role_mappings].transform_values { |groups| groups.map(&:downcase) }
  end
end
