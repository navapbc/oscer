# frozen_string_literal: true

# Feature flag system for controlling feature rollout
# Flags are controlled via environment variables
module Features
  class << self
    # Check if batch upload v2 features are enabled
    # @return [Boolean] true if FEATURE_BATCH_UPLOAD_V2 env var is "true"
    def batch_upload_v2_enabled?
      ENV.fetch("FEATURE_BATCH_UPLOAD_V2", "false") == "true"
    end
  end
end
