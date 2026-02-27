# frozen_string_literal: true

# DocAI Integration Configuration
#
# Required environment variables:
#   DOC_AI_API_HOST - DocAI API base endpoint
#
# Optional environment variables:
#   DOC_AI_TIMEOUT_SECONDS          - HTTP timeout in seconds (default: 60)
#   DOC_AI_LOW_CONFIDENCE_THRESHOLD - Minimum confidence threshold (default: 0.7)
#   DOC_AI_THREAD_POOL_SIZE         - Concurrent::FixedThreadPool size (default: 4)

Rails.application.config.doc_ai = {
  api_host:                 ENV.fetch("DOC_AI_API_HOST", nil),
  timeout_seconds:          ENV.fetch("DOC_AI_TIMEOUT_SECONDS", "60").to_i,
  low_confidence_threshold: ENV.fetch("DOC_AI_LOW_CONFIDENCE_THRESHOLD", "0.7").to_f,
  thread_pool_size:         ENV.fetch("DOC_AI_THREAD_POOL_SIZE", "4").to_i
}.freeze
