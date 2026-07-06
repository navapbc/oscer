# Feature flags and partial releases

Feature flags are an important tool that enables [trunk-based development](https://trunkbaseddevelopment.com/). They allow in-progress features to be merged into the main branch while still allowing that branch to be deployed to production at any time, thus decoupling application deploys from feature releases. For a deeper introduction, [Martin Fowler's article on Feature Toggles](https://martinfowler.com/articles/feature-toggles.html) and [LaunchDarkly's blog post on feature flags](https://launchdarkly.com/blog/what-are-feature-flags/) are both great articles that explain the what and why of feature flags.

## How it works

Feature flags are read at runtime from `FEATURE_<NAME>` environment variables by the `Features` module in [`config/initializers/feature_flags.rb`](/reporting-app/config/initializers/feature_flags.rb). Flags come from two sources, unioned into one registry at boot: OSCER-shipped built-ins in the `Features::FEATURE_FLAGS` hash, and deployment-defined flags in `config/custom/feature_flags.yml`.

## Create a feature flag

Add an OSCER-shipped built-in by adding an entry (`env_var`, `default`, `description`) to the `FEATURE_FLAGS` hash in `config/initializers/feature_flags.rb`. A deployment adds its own flag by adding an entry to `config/custom/feature_flags.yml` instead, which avoids editing the OSCER-owned registry and conflicting on every upstream sync. See [CUSTOMIZATION.md](/reporting-app/CUSTOMIZATION.md) for the deployment-defined workflow and validation rules.

## Set a feature flag value for an environment

Set a flag's value for an environment in the `service_override_extra_environment_variables` block of that environment's app-config file (`infra/reporting-app/app-config/<env>.tf`), as `FEATURE_DOC_AI` and `FEATURE_DEMO_CERTIFICATIONS` do. The value takes effect on the next `terraform apply` of the service layer, or during the next deploy of the application. A flag left unset falls back to the `default` in its registry entry.

## Query a feature flag value in the application

To determine whether a feature is enabled, call `Features.<flag>_enabled?` (e.g. `Features.doc_ai_enabled?`) or the generic `Features.enabled?(:flag_name)`. Both are generated automatically for every registered flag. In specs, use the auto-generated `with_<flag>_enabled` / `with_<flag>_disabled` block helpers from `spec/support/feature_flag_helpers.rb`.

## DocAI operational configuration (not feature flags)

Scheduled cleanup of orphaned uploaded documents uses separate environment variables (`STAGED_DOCUMENT_CLEANUP_ENABLED`, `STAGED_DOCUMENT_RETENTION_DAYS`, `STAGED_DOCUMENT_CLEANUP_SCHEDULE`). These are loaded in `config/initializers/doc_ai.rb` and documented in [DocAI integration](architecture/doc-ai-integration/doc-ai-api.md#staged-document-cleanup).
