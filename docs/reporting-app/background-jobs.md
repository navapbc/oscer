# Background jobs

OSCER uses [GoodJob](https://github.com/bensheldon/good_job) as its ActiveJob backend. GoodJob is database-backed (PostgreSQL), so it doesn't require a separate Redis instance or worker process.

## How GoodJob runs

GoodJob is configured in `reporting-app/config/initializers/good_job.rb`.

Key settings:

- **Execution mode**: `:async` — jobs run in the web process (no separate worker containers)
- **Max threads**: 2 (configurable via `GOOD_JOB_MAX_THREADS`) — kept lower than Puma to avoid DB connection exhaustion
- **Job preservation**: Finished jobs are kept for 1 week for debugging and metrics

## Adding a scheduled (cron) job

Scheduled jobs are configured in `config/initializers/good_job.rb` under `config.good_job.cron`. Each entry specifies a cron expression, job class, and description:

```ruby
config.good_job.cron = {
  purge_unattached_blobs: {
    cron: "0 3 * * *",                # Daily at 3 AM
    class: "PurgeUnattachedBlobsJob",
    description: "Clean up orphaned Active Storage blobs from abandoned uploads"
  },
  cleanup_staged_documents: {
    cron: Rails.application.config.doc_ai[:staged_document_cleanup_schedule],
    class: "CleanupStagedDocumentsJob",
    description: "Delete orphaned DocAI StagedDocuments past retention"
  },
  my_new_scheduled_job: {
    cron: "*/15 * * * *",             # Every 15 minutes
    class: "MyNewScheduledJob",
    description: "What this job does"
  }
}
```

Cron syntax uses five fields: `minute hour day-of-month month day-of-week`. See [crontab.guru](https://crontab.guru) for help building expressions.

### Monitoring scheduled jobs

GoodJob provides a web dashboard at `/good_job` where you can view job history, cron schedules, and failures. Access requires authentication and is gated by the `GoodJobPolicy#dashboard?` Pundit policy.

## Infrastructure

In deployed environments, background jobs may also be triggered by cloud infrastructure events (e.g., S3 uploads triggering EventBridge rules). See [docs/infra/background-jobs.md](../infra/background-jobs.md) for infrastructure-level job configuration.
