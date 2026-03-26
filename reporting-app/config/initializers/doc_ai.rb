# frozen_string_literal: true

# DocAI Integration Configuration
#
# Environment variables:
#   DOC_AI_API_HOST                 - DocAI API base endpoint (default: platform-test-dev endpoint)
#   DOC_AI_TIMEOUT_SECONDS          - HTTP timeout in seconds (default: 60)
#   DOC_AI_LOW_CONFIDENCE_THRESHOLD - Minimum confidence threshold (default: 0.7)
#   STAGED_DOCUMENT_CLEANUP_ENABLED - Enable rake cleanup of orphaned staged docs (default: true)
#   STAGED_DOCUMENT_RETENTION_DAYS  - Age in days before orphaned docs are deleted (default: 7)
#   STAGED_DOCUMENT_CLEANUP_SCHEDULE - Cron expression for when to run cleanup (docs only; default: 0 2 * * *)

Rails.application.config.doc_ai = {
  api_host:                        ENV.fetch("DOC_AI_API_HOST", nil),
  timeout_seconds:                 ENV.fetch("DOC_AI_TIMEOUT_SECONDS", "60").to_i,
  low_confidence_threshold:        ENV.fetch("DOC_AI_LOW_CONFIDENCE_THRESHOLD", "0.7").to_f,
  staged_document_cleanup_enabled: ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("STAGED_DOCUMENT_CLEANUP_ENABLED", "true")
  ),
  staged_document_retention_days:  ENV.fetch("STAGED_DOCUMENT_RETENTION_DAYS", "7").to_i,
  staged_document_cleanup_schedule: ENV.fetch("STAGED_DOCUMENT_CLEANUP_SCHEDULE", "0 2 * * *")
}.freeze

Rails.application.config.to_prepare do
  # Eager load DocAiResult subclasses to populate the registry
  Dir[Rails.root.join("app/models/doc_ai_result/*.rb")].each do |file|
    "DocAiResult::#{File.basename(file, ".rb").camelize}".constantize
  end
end
