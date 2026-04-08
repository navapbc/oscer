# frozen_string_literal: true

require 'open3'

# Helpers for specs where ENV is read at file load time (e.g. class-level constants).
# In-process helpers such as +stub_const('ENV', ...)+ (see Cognito config specs) or
# +FeatureFlagHelpers#with_env+ only affect code that reads ENV when a method runs.
# For load-time reads, spawn a child Ruby with merged env (same idea as +Open3+, not
# mutating the parent process).
#
# Compare: +spec/requests/auth/sso_redirect_and_member_oidc_spec.rb+ +with_env+ for
# in-process overrides used during an example block.
module SubprocessEnvHelpers
  # Loads +path+ in a fresh +ruby+ process after merging +env_overrides+ into the
  # child environment (Open3 merge semantics).
  #
  # @param env_overrides [Hash<String, String>] merged into the subprocess ENV
  # @param path [Pathname, String] file passed to Kernel#load
  # @return [Array(String, Process::Status)] combined stdout/stderr, exit status
  def capture_ruby_load_with_env(env_overrides, path)
    expanded = File.expand_path(path.to_s)
    script = <<~RUBY
      require 'bigdecimal'
      load #{expanded.inspect}
    RUBY

    Open3.capture2e(env_overrides, Gem.ruby, '-e', script)
  end
end

RSpec.configure do |config|
  config.include SubprocessEnvHelpers
end
