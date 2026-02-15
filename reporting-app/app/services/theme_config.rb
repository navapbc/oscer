# frozen_string_literal: true

# Loads and provides access to theme configuration for OSCER deployments
#
# Reads configuration from config/themes.yml and selects the active theme
# based on the OSCER_THEME environment variable. Falls back to 'default'
# theme when env var is not set or references an unknown theme.
#
# Usage:
#   # Get the current theme configuration
#   theme = ThemeConfig.current
#   theme.name            # => "State of Nava PBC"
#   theme.primary_color   # => "#1a3d5c"
#
#   # For testing: Reset cached instance
#   ThemeConfig.reset!
#
# Configuration is frozen after load to ensure immutability.
#
class ThemeConfig
  class ConfigurationError < StandardError; end

  DEFAULT_THEME = "default"
  CONFIG_PATH = Rails.root.join("config/themes.yml")

  class << self
    # Returns the current theme configuration (cached singleton)
    # @return [ThemeConfig]
    def current
      @current ||= load_theme
    end

    # Resets the cached instance (useful for testing)
    def reset!
      @current = nil
    end

    private

    def load_theme
      theme_key = ENV.fetch("OSCER_THEME", DEFAULT_THEME)
      themes = load_themes_file

      unless themes.key?(theme_key)
        Rails.logger.warn "[Theme] Unknown theme '#{theme_key}', falling back to default"
        theme_key = DEFAULT_THEME
      end

      new(theme_key, themes[theme_key])
    end

    def load_themes_file
      unless File.exist?(CONFIG_PATH)
        raise ConfigurationError, "Theme configuration not found: #{CONFIG_PATH}"
      end

      # Use safe_load for security (prevents arbitrary code execution)
      yaml_content = File.read(CONFIG_PATH)
      YAML.safe_load(yaml_content, permitted_classes: [], permitted_symbols: [], aliases: true)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
      raise ConfigurationError, "Invalid YAML in theme configuration: #{e.message}"
    end
  end

  attr_reader :theme_key

  def initialize(theme_key, config)
    @theme_key = theme_key
    @config = config.deep_symbolize_keys.freeze
  end

  # @return [String] Display name for the application
  def name
    @config[:name]
  end

  # @return [String] Full agency name
  def agency_name
    @config[:agency_name]
  end

  # @return [String] Primary brand color (hex)
  def primary_color
    @config[:primary_color]
  end

  # @return [String] Secondary brand color (hex)
  def secondary_color
    @config[:secondary_color]
  end

  # @return [String] Accent color (hex)
  def accent_color
    @config[:accent_color]
  end

  # @return [String] Background color (hex)
  def background_color
    @config[:background_color]
  end

  # @return [String] Text color (hex)
  def text_color
    @config[:text_color]
  end

  # @return [String] Logo filename
  def logo
    @config[:logo]
  end

  # @return [String] Favicon filename
  def favicon
    @config[:favicon]
  end

  # @return [String] Contact email address
  def contact_email
    @config[:contact_email]
  end

  # @return [String, nil] Banner text (nil if no banner)
  def banner_text
    @config[:banner_text]
  end

  # @return [Array<Hash>] Footer links with :label and :url keys
  def footer_links
    @config[:footer_links] || []
  end

  # @return [Boolean] True if a banner should be displayed
  def banner?
    banner_text.present?
  end

  # @return [Boolean] True if this is the default theme
  def default?
    theme_key == DEFAULT_THEME
  end
end
