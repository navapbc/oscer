# frozen_string_literal: true

class Region
  CONFIG_FILE = Rails.root.join("config", "regions.yml")

  attr_reader :key, :name

  def initialize(key, attributes)
    @key = key.to_s
    @name = attributes["name"]
  end

  def self.load_config
    @config ||= YAML.load_file(CONFIG_FILE)["regions"].freeze
  end

  def self.all
    @all ||= load_config.map { |key, attrs| new(key, attrs) }.freeze
  end

  def self.keys
    @keys ||= all.map(&:key).freeze
  end
end
