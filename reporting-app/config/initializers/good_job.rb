# frozen_string_literal: true

Rails.application.configure do
  # Run jobs in web process (no separate worker containers)
  config.good_job.execution_mode = :async

  # Use same thread pool size as Puma
  config.good_job.max_threads = ENV.fetch("RAILS_MAX_THREADS", 5).to_i

  # Process all queues
  config.good_job.queues = "*"

  # Enable cron for future scheduled jobs
  config.good_job.enable_cron = true

  # Retry failed jobs automatically
  config.good_job.retry_on_unhandled_error = true

  # Poll interval for new jobs (1 second)
  config.good_job.poll_interval = 1

  # Shutdown timeout (30 seconds to finish in-flight jobs)
  config.good_job.shutdown_timeout = 30

  # Preserve finished jobs for 1 week (for debugging/metrics)
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
end
