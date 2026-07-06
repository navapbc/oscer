# frozen_string_literal: true

require "tempfile"

# Shared helper for config-loader specs. Writes content to a tempfile and returns the closed
# Tempfile; callers `.unlink` in an `after` block and pass `.path`. Extracted from the previously
# duplicated `write_yaml` defs in the loader specs. The `prefix:` kwarg preserves a per-spec
# tempfile prefix when wanted but defaults generically, so existing `write_yaml("...")` call sites
# are unchanged (nothing asserts on filenames).
module YamlConfigHelpers
  def write_yaml(content, prefix: "yaml_config_test")
    file = Tempfile.new([ prefix, ".yml" ])
    file.write(content)
    file.close
    file
  end
end

RSpec.configure do |config|
  config.include YamlConfigHelpers
end
