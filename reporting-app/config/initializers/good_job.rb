# frozen_string_literal: true

Rails.application.configure do
  # Run jobs in web process (no separate worker containers)
  config.good_job.execution_mode = :async

  # Use fewer threads than Puma to avoid DB connection exhaustion
  # Pool size: Puma (5) + GoodJob (2) + buffer (1) = 8
  config.good_job.max_threads = ENV.fetch("GOOD_JOB_MAX_THREADS", 2).to_i

  # Scope jobs to this environment to prevent cross-environment execution
  # when multiple environments share the same database (e.g., dev + preview).
  # GOOD_JOB_QUEUE_PREFIX is set per ECS task by terraform (local.service_name).
  #
  # Note: We use "_" as the delimiter (not ":") because GoodJob's queues config
  # format uses ":" as a thread-count delimiter (e.g., "queue_name:2"). Using ":"
  # in queue names causes GoodJob to misparse them (e.g., "prefix:default" becomes
  # queue "prefix" with 0 threads).
  queue_prefix = ENV["GOOD_JOB_QUEUE_PREFIX"]
  if queue_prefix.present?
    config.active_job.queue_name_prefix = queue_prefix
    config.active_job.queue_name_delimiter = "_"
    prefixed_queues = %w[default].map { |q| "#{queue_prefix}_#{q}" }.join(",")
    config.good_job.queues = prefixed_queues
  else
    config.good_job.queues = "*"
  end

  # Enable cron for scheduled jobs
  config.good_job.enable_cron = true
  config.good_job.cron = {
    purge_unattached_blobs: {
      cron: "0 3 * * *",
      class: "PurgeUnattachedBlobsJob",
      description: "Clean up orphaned Active Storage blobs from abandoned uploads"
    },
    cleanup_staged_documents: {
      cron: Rails.application.config.doc_ai[:staged_document_cleanup_schedule],
      class: "CleanupStagedDocumentsJob",
      description: "Delete orphaned StagedDocuments past retention (see STAGED_DOCUMENT_* env vars)"
    }
  }

  # Don't retry unhandled errors automatically. Jobs that need retries should
  # declare specific retry_on handlers with bounded attempts and backoff.
  # Global retry with zero delay caused an OOM retry storm in production.
  config.good_job.retry_on_unhandled_error = false

  # Poll interval for new jobs (1 second)
  config.good_job.poll_interval = 1

  # Shutdown timeout (30 seconds to finish in-flight jobs)
  config.good_job.shutdown_timeout = 30

  # Preserve finished jobs for 1 week (for debugging/metrics)
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
end
