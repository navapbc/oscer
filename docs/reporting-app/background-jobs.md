# Background jobs

OSCER uses [GoodJob](https://github.com/bensheldon/good_job) as its ActiveJob backend. GoodJob is database-backed (PostgreSQL), so it doesn't require a separate Redis instance or worker process.

## How GoodJob runs

GoodJob is configured in `reporting-app/config/initializers/good_job.rb`.

Key settings:

- **Execution mode**: `:async` — jobs run in the web process (no separate worker containers)
- **Max threads**: 2 (configurable via `GOOD_JOB_MAX_THREADS`) — kept lower than Puma to avoid DB connection exhaustion
- **Job preservation**: Finished jobs are kept for 1 week for debugging and metrics

## Creating a background job

Background jobs live in `app/jobs/` and inherit from `ApplicationJob`:

```ruby
# app/jobs/my_job.rb
class MyJob < ApplicationJob
  def perform(some_id)
    record = SomeModel.find(some_id)
    # Business logic here
  end
end
```

Enqueue from controllers or services:

```ruby
MyJob.perform_later(record.id)
```

### Testing jobs

Job specs live in `spec/jobs/` and use `ActiveJob::TestHelper`:

```ruby
RSpec.describe MyJob, type: :job do
  include ActiveJob::TestHelper

  it "does the thing" do
    described_class.perform_now(record.id)
    expect(record.reload).to be_processed
  end
end
```

### Strict loading

This app has `config.active_record.strict_loading_by_default = true`. If your job loads ActiveRecord objects and accesses associations, you'll need `.includes(...)` to eager-load them. Without this, you'll get `ActiveRecord::StrictLoadingViolationError`.

## Adding a scheduled (cron) job

Scheduled jobs are configured in `config/initializers/good_job.rb` under `config.good_job.cron`. Each entry specifies a cron expression, job class, and description:

```ruby
config.good_job.cron = {
  purge_unattached_blobs: {
    cron: "0 3 * * *",                # Daily at 3 AM
    class: "PurgeUnattachedBlobsJob",
    description: "Clean up orphaned Active Storage blobs from abandoned uploads"
  },
  my_new_scheduled_job: {
    cron: "*/15 * * * *",             # Every 15 minutes
    class: "MyNewScheduledJob",
    description: "What this job does"
  }
}
```

Cron syntax uses five fields: `minute hour day-of-month month day-of-week`. See [crontab.guru](https://crontab.guru) for help building expressions.

### Steps to add a scheduled job

1. Create the job class in `app/jobs/`
2. Add the cron entry to `config/initializers/good_job.rb`
3. Add specs in `spec/jobs/`

### Monitoring scheduled jobs

GoodJob provides a web dashboard (mounted in routes) where you can view job history, cron schedules, and failures.

## Infrastructure

In deployed environments, background jobs may also be triggered by cloud infrastructure events (e.g., S3 uploads triggering EventBridge rules). See [docs/infra/background-jobs.md](../infra/background-jobs.md) for infrastructure-level job configuration.
