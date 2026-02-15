# frozen_string_literal: true

# Preload theme configuration on application startup
#
# This ensures:
# 1. Configuration errors are caught at boot time, not first request
# 2. Theme is cached and ready for immediate use
# 3. Missing/invalid OSCER_THEME env var logs warning early
#
Rails.application.config.after_initialize do
  ThemeConfig.current
end
