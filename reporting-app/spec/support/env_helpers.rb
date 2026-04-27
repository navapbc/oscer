# frozen_string_literal: true

# Temporarily replace ENV entries for a block (restores previous values, deletes keys
# that were unset before the block).
module EnvHelpers
  def with_env(overrides, &block)
    old = {}
    overrides.each do |key, value|
      old[key] = ENV[key]
      ENV[key] = value
    end
    block.call
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end
