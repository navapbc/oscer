# OSCER Customization & Extension Architecture

**Companion to:** [OSCER Open Source Update Strategy](./update-strategy.md)
**Date:** 2026-04-28 (last updated 2026-05-20)
**Author:** Michael Giver
**Status:** Living document — published to the OSCER repo via [#620](https://github.com/navapbc/oscer/issues/620); updated as implementation evolves

## Executive Summary

**Goal:** Enable implementers to adopt OSCER, customize for their deployment, and pull upstream updates with minimal merge conflicts. This spec is the implementation-detail companion to the parent OSCER Open Source Update Strategy doc, which covers the repository strategy (Copier template, `nava-platform` flow), Extension Contract, and release cadence. This spec details the file-level customization mechanics.

**Context:** OSCER's design assumption is that most variance between deployments will belong in configuration, not code. The working-assumptions doc (`docs/hr1-working-assumptions.md`) names a narrow set of items open to each deployment: exemption list composition (above the federal floor) and documentation requirements (attestation vs. document-verified). Other rules (compliance pathways, thresholds, exemption criteria) are federally opinionated and stay in Ruby; see Layer 1's scope note for the working list. The current code has an implementation gap where state-configurable policy is hardcoded in Ruby initializers; closing that gap is in scope for the implementation roadmap (Phase 1).

**Core Principle:** Implementers should rarely edit base files. Customizations live in deployment-owned files at fixed paths (YAML configs, locale overrides, branding override hooks, subclassed Ruby classes, model concerns). Behavioral differences beyond the federal floor use the code-level patterns described in Layer 4. Federally-opinionated rules are not customizable through this spec; see Layer 1's scope note for the working list and how to escalate.

---

## Naming conventions

Deployment-owned files use one of two naming patterns:

| Pattern | Used for | Source of convention |
|---|---|---|
| `overrides/`, `_overrides.scss`, `custom.scss` | View, mailer, and CSS overrides | `template-application-rails` ([PR #166](https://github.com/navapbc/template-application-rails/pull/166)), upstream source of truth |
| `Custom::`, `custom/`, `config/custom/` | Net-new Ruby code (subclasses, concerns, new models, rulesets) and Tier 1 per-concern YAML overrides | This spec |
| `config/locales/overrides/` | Locale string overrides | This spec — chosen for Rails-native `config/locales/**` recursive auto-discovery |

The view, mailer, and CSS naming follows upstream because that's where the override mechanism is defined: `ApplicationController` and `ApplicationMailer` `prepend_view_path` `app/views/overrides/`, and `application.scss` `@forward`s `_overrides.scss` last so deployment rules cascade after USWDS. The Ruby and Tier 1 YAML naming is this spec's own convention: `Custom::` (and `custom/` subdirectories) namespace deployment-specific code, `config/custom/<concern>.yml` holds Tier 1 per-concern overrides, and `config/locales/overrides/` holds deployment-owned locale files loaded after all base locales by explicit `config/application.rb` plumbing.

---

## Deployment Onboarding

When an implementer first renders OSCER from the Copier template (see "Workflow for Implementers" at the bottom of this doc for the install mechanics), the rendered project is fully functional with safe defaults: no exemption customizations, no deployment-specific branding, demo routes disabled. Onboarding is the work of layering in deployment-specific customizations on top of that baseline.

The customization layers below describe **what** to customize. Onboarding typically follows this order:

1. **Branding** (Layer 3): drop deployment colors, fonts, and logo into `_overrides.scss` and `app/views/overrides/layouts/`. Verify the app renders with the deployment's identity before deeper work.
2. **Translations** (Layer 2): drop YAML files under `config/locales/overrides/` for any deployment-specific UI copy (e.g., "Member" → "Participant").
3. **Domain config** (Layer 1): edit `config/custom/exemption_types.yml` to declare deployment-specific exemption customizations. Federal-floor defaults are template-owned and shipped in code; the override file is optional.
4. **Behavioral customizations** (Layers 4 and 5): only if the deployment needs net-new eligibility paths or model fields beyond the federal floor.

---

## Production Hardening

Operational toggles separate from the customization ladder. These aren't deployment-specific customizations; they're hardening defaults that production deployments MUST configure regardless of what else they customize.

### Demo mode

OSCER includes `/demo` routes (`GET /demo`, `GET/POST /demo/certifications`) that scaffold sample certifications for development and reviewer demos. **Production deployments MUST disable these routes**. They expose certification-creation flows without authentication and would let any visitor create data in a live environment.

The `/demo` namespace in `config/routes.rb` is gated behind a single env var:

```ruby
# config/routes.rb
if ENV["OSCER_DEMO_MODE"] == "true"
  get "/demo", to: "demo#index"
  namespace :demo do
    resources :certifications, only: [ :new, :create ]
  end
end
```

The env var defaults to unset (treated as `false`), so production deployments that don't opt in inherit the safe default. Development and preview environments may set `OSCER_DEMO_MODE=true` to access the demo flows.

**Conflict risk:** Zero. Implementers don't edit routes themselves; the gating is a one-time base file change Nava ships in Phase 1 (see "What Nava Must Do to Enable This"), and deployments just leave the env var unset in production.

---

## Customization Layers

OSCER deploys one instance per implementer (state-hosted, state-owned; not multi-tenant). Customizations live at fixed paths in the rendered project: no dispatch mechanism, no env-var-driven namespace selection. A single initializer loads them at boot.

> **Note on file organization:** Earlier drafts of this spec used customer-named subdirectories (`config/state_configs/colorado.yml`, `app/views/states/colorado/`) selected via an `ENV["STATE"]` lookup. That mechanism was unnecessary for OSCER's one-deployment-per-implementer model and baked "state" framing into infrastructure that should be implementer-neutral (tribal governments, territories, sub-state programs all deploy as peers). All customization paths below are fixed; the env var is gone.

### Layer 1: Domain Config (code defaults + optional YAML override)

For deployment-varying data such as exemption types and documentation requirements. No Ruby needed for the common case.

**Federal-floor defaults (template-owned, declared in code):**
```ruby
# app/services/exemption_types_loader.rb
module ExemptionTypesLoader
  DEFAULTS = {
    "caregiver_disability"   => { "enabled" => true },
    "caregiver_child"        => { "enabled" => true },
    "medical_condition"      => { "enabled" => true },
    "substance_treatment"    => { "enabled" => true },
    "incarceration"          => { "enabled" => true },
    "education_and_training" => { "enabled" => true },
    "received_medical_care"  => { "enabled" => true }
  }.freeze
  # ...
end
```

Defaults live in the per-concern loader module rather than a separate YAML file because the federal floor isn't deployment-configurable — it's updated by Nava as CMS regulations evolve, shipped via template releases. Hoisting them into a frozen Ruby constant dissolves the awkward "base YAML + deep-merged override YAML" pairing where only the override layer ever varied.

**Deployment override (optional; deep-merged over defaults):**
```yaml
# config/custom/exemption_types.yml
medical_condition:
  enabled: false          # Disable a default exemption
disaster_evacuation:
  enabled: true           # Add a deployment-specific exemption
wildfire_displacement:
  enabled: true           # Add another
```

The override YAML is deep-merged over `DEFAULTS`. Implementers only declare what's different: additions, removals (via `enabled: false`), or overrides. Everything not mentioned inherits from the defaults. The override file is genuinely optional — deployments that don't customize exemption types can delete the file entirely, and the loader treats a missing or empty file as "no overrides."

**Per-concern file layout:** Each Tier 1 concern gets its own file under `config/custom/`. Today's surface is exemption types (`config/custom/exemption_types.yml`); the next planned concern is documentation requirements, which will land as `config/custom/documentation_requirements.yml` with its own loader module (`DocumentationRequirementsLoader::DEFAULTS`). Copier's `_skip_if_exists` directive preserves each Tier 1 override file across `nava-platform app update`. It lists files individually (`config/custom/exemption_types.yml` today, not a directory glob), so each future Tier 1 concern must be added to the directive explicitly.

> **Scope note (federally-opinionated rules):** Tier 1 is for items the working-assumptions doc names as state-configurable: exemption list composition (above the federal floor) and documentation requirements (attestation vs. document-verified). Other rules are federally opinionated and stay in Ruby. Examples include the 80-hour activity threshold, $580 income threshold, hours-or-income non-combinability, activity category definitions, medically-frail breadth, and VA disability rating. Implementers who think one of these needs to change should bring it upstream as a policy discussion, not encode it in `config/custom/`. See parent strategy doc Section 4's "What you should NOT customize" subsection for the canonical list.

> **Implementation note:** The override YAML uses a hash-of-hashes structure for exemption-type entries (keyed by type name) to enable deep-merge. The current `Exemption` model expects an array of hashes with symbol keys (`[{id: :caregiver_disability, enabled: true}, ...]`). The loader (see "The Initializer" below) includes a transformation step that bridges this, converting the merged hash into the array format the model consumes. This means the `Exemption` model requires no changes.

**Conflict risk:** Zero. The override file lives at a deployment-owned path (`config/custom/`); the defaults live in template-owned Ruby code. The two never share a file.

---

### Layer 2: Translation Overrides

For UI copy, terminology, and deployment-specific language. Implementers create locale files under `config/locales/overrides/` — a deployment-owned subdirectory of OSCER's standard `config/locales/` tree. Files can be flat (single-file overrides for small deployments) or mirror OSCER's `views/`, `models/`, etc. subdirectory structure (recommended for deployments with many overrides; makes it visually clear which OSCER file each override shadows).

```yaml
# config/locales/overrides/views/application/my-state.en.yml
en:
  views:
    application:
      title: "MyState Community Engagement Reporting"
```

```yaml
# config/locales/overrides/exemption_types.en.yml
en:
  exemption_types:
    disaster_evacuation:
      title: "Disaster Evacuation or Displacement"
      description: "Evacuated due to wildfire or natural disaster"
      question: "Have you been evacuated in the past 30 days?"
```

**Load ordering (explicit two-step plumbing in `config/application.rb`):**

```ruby
base_locales = Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  .reject { |p| p.include?("/locales/overrides/") }
override_locales = Dir[Rails.root.join("config", "locales", "overrides", "**", "*.{rb,yml}")]
config.i18n.load_path += base_locales + override_locales
```

Rails I18n is load-order-based — when multiple files define the same key, the last-loaded value wins. The two-step plumbing loads OSCER's base locale files first (everything under `config/locales/` *except* `overrides/`), then loads override files last so deployment keys always win on conflict.

> **Why explicit ordering is required:** OSCER's locale subdirectories include `services/`, `views/`, and others that sort alphabetically *after* `overrides/` under a naive recursive glob. A single-glob `Dir[config/locales/**/*.{rb,yml}]` would load `overrides/foo.en.yml` *before* `services/foo.en.yml` and `views/foo.en.yml`, letting base keys in those subdirectories beat deployment overrides. The two-step plumbing makes the ordering robust against adding new OSCER locale subdirectories — future `config/locales/<new-dir>/` files automatically slot into the base step regardless of alphabetical position.

**Conflict risk:** Zero. The `overrides/` subdirectory is deployment-owned; OSCER never ships content there (only a `README.md` explainer). Implementer-created files live at paths the template doesn't manage, so Copier doesn't touch them on `nava-platform app update`.

---

### Layer 3: View and Branding Customization

Branding and visual customization use the override mechanism that ships in `template-application-rails` ([PR #166](https://github.com/navapbc/template-application-rails/pull/166), upstream of OSCER's template). OSCER inherits this mechanism by virtue of being rendered from the rails template, so this spec defers to that PR for the wiring detail and only summarizes the deployment-facing surface here.

**Three deployment-owned override hooks ship at fixed paths:**

| Hook | Purpose | Mechanism |
|---|---|---|
| `app/assets/stylesheets/_overrides.scss` | CSS overrides (colors, fonts, component tweaks) | `application.scss` `@forward`s this last so deployment rules win |
| `app/assets/stylesheets/custom.scss` | Full alternative stylesheet | Compiles to a separate `custom.css`; swap `stylesheet_link_tag "application"` → `"custom"` in the layout to use it |
| `app/views/overrides/` | View **and** mailer template overrides | `ApplicationController` and `ApplicationMailer` both `prepend_view_path` this directory |

For most branding (colors, typography, button styling, spacing tweaks), `_overrides.scss` is enough: anything added there cascades after USWDS and the template's own `_uswds-overrides.scss`, so it wins. `custom.scss` exists for deployments that want full control over the compiled stylesheet rather than additive overrides.

View overrides follow Rails' template resolver: place a file at `app/views/overrides/dashboard/show.html.erb` and Rails finds it before the base `app/views/dashboard/show.html.erb`. The same directory handles mailer templates because `ApplicationMailer` shares the same `prepend_view_path`, which means deployment-specific email layouts and notification templates work the same way.

```
app/views/overrides/
  layouts/application.html.erb        # Custom layout (header, footer, logo)
  dashboard/show.html.erb             # Custom dashboard
  member_mailer/notification.html.erb # Custom mailer template
```

**Conflict risk:** Zero for deployment-owned files (separate paths from base). Overridden views and mailers carry a staleness caveat: if Nava modifies the base template, the deployment's override doesn't pick up the change. Release changelogs should flag base view and mailer changes.

**What's NOT in this layer:** Direct edits to base view files (`app/views/dashboard/show.html.erb`) and direct edits to `_uswds-theme.scss` (Nava's USWDS variable settings) remain available as last-resort options if the override hooks don't suffice. Both carry merge conflict risk on every upstream update; reach for them only when `_overrides.scss` and `app/views/overrides/` genuinely can't express the change.

---

### Layer 4: Service and Ruleset Customization

For genuinely behavioral differences: adding eligibility paths beyond the federal floor, calling deployment-specific external services, or custom determination workflows. Pattern: **subclass and rewire**.

> **Note on `Strata::RulesEngine`:** Ruleset methods receive declared facts as positional arguments; the names must match facts the engine sets via `set_facts`. To extend the ruleset, add new fact methods and override the composition method (`eligible_for_exemption`) to incorporate them.

**Step 1: Implementer creates a subclass (new file, zero conflict):**

```ruby
# app/models/rules/custom/exemption_ruleset.rb
class Rules::Custom::ExemptionRuleset < Rules::ExemptionRuleset
  # Add a deployment-specific exemption eligibility path beyond the federal
  # floor (e.g., disaster evacuation tied to a state-maintained registry).
  def eligible_for_disaster_exemption(disaster_status)
    disaster_status == true
  end

  def eligible_for_exemption(age_under_19, age_over_65, is_pregnant,
                              is_american_indian_or_alaska_native,
                              is_veteran_with_disability,
                              eligible_for_disaster_exemption)
    facts = [age_under_19, age_over_65, is_pregnant,
             is_american_indian_or_alaska_native,
             is_veteran_with_disability,
             eligible_for_disaster_exemption]
    return if facts.all?(&:nil?)

    facts.any?
  end
end
```

**Step 2: Implementer rewires the one line that instantiates it:**

```ruby
# app/services/exemption_determination_service.rb
# In evaluate_exemption_eligibility, the line: ruleset = Rules::ExemptionRuleset.new
# BEFORE (base OSCER):
ruleset = Rules::ExemptionRuleset.new

# AFTER (deployment edits this one line):
ruleset = Rules::Custom::ExemptionRuleset.new
```

**Conflict risk:** Very low; conflicts arise only if Nava changes the specific instantiation line. All other changes to the service file merge cleanly.

**Same pattern for services:**

```ruby
# app/services/custom/exemption_determination_service.rb (new file)
module Custom
  class ExemptionDeterminationService < ::ExemptionDeterminationService
    class << self
      private

      def evaluate_exemption_eligibility(certification)
        # Deployment-specific: check external disaster registry before standard evaluation
        disaster_status = check_disaster_registry(certification)

        ruleset = Rules::Custom::ExemptionRuleset.new
        engine = Strata::RulesEngine.new(ruleset)

        engine.set_facts(
          # ... federal facts inherited from base service ...
          disaster_status: disaster_status
        )

        engine.evaluate(:eligible_for_exemption)
      end

      def check_disaster_registry(certification)
        # Deployment-specific: call external disaster API
      end
    end
  end
end
```

Rewire in `app/business_processes/certification_business_process.rb` (in the `EXTERNAL_EXEMPTION_CHECK_STEP` system_process block): replace `ExemptionDeterminationService.determine(kase)` with `Custom::ExemptionDeterminationService.determine(kase)`.

---

### Layer 5: Model Customization

For adding fields, validations, scopes, or methods to existing models.

**Adding columns (zero base file edits):**

Implementers write a migration (new file). Rails automatically discovers new columns. `certification.county` works without declaring it in the model class.

```ruby
# db/migrate/20260408_add_county_to_certifications.rb
class AddCountyToCertifications < ActiveRecord::Migration[8.0]
  def change
    add_column :certifications, :county, :string
  end
end
```

> **Note on `schema.rb`:** Deployments with custom migrations will see merge conflicts in `db/schema.rb` on every upstream update that includes migrations. **Don't manually resolve this.** Accept either version and run `rails db:migrate`, which regenerates `schema.rb` from the full migration history. Optionally, add `db/schema.rb merge=ours` to `.gitattributes` so git auto-accepts the deployment's version during merges.

**Adding validations, scopes, or methods (one `include` line):**

Implementer creates a concern (new file), adds one `include` line to the base model:

```ruby
# app/models/concerns/custom/certification_extensions.rb
module Custom::CertificationExtensions
  extend ActiveSupport::Concern

  included do
    validates :county, presence: true
  end

  def in_disaster_zone?
    DisasterZoneService.active_counties.include?(county)
  end
end
```

```ruby
# app/models/certification.rb (deployment adds one line):
include Custom::CertificationExtensions
```

**Conflict risk:** Very low. One `include` line at the top of the model. Changes to the rest of the model merge cleanly. Multiple concerns can coexist (if Nava also adds concerns, both `include` lines merge since they're on different lines).

**Adding new models (zero base file edits):**

Implementers namespace under `Custom::`:

```ruby
# app/models/custom/disaster_declaration.rb
module Custom
  class DisasterDeclaration < ApplicationRecord
    # ...
  end
end
```

With a corresponding migration. Entirely new files, zero conflict.

---

## The Initializer

Each Tier 1 concern gets its own thin initializer that wires the loader module's defaults to an optional override file at a fixed path. No environment variable, no namespace selection. The override file is conditional — a deployment that hasn't customized a given concern pays no cost (the loader treats a missing or empty file as "no overrides").

The YAML-load + merge + transform logic for each concern is extracted into a small per-concern loader module so failure modes can be unit-tested without booting Rails. The initializer is a thin wrapper.

```ruby
# config/initializers/exemption_types.rb

# Zeitwerk autoloading is not available during initializers, so require explicitly.
require Rails.root.join("app/services/exemption_types_loader")

override_path = Rails.root.join("config/custom/exemption_types.yml")
overrides     = ExemptionTypesLoader.safe_load_optional(override_path)
merged        = ExemptionTypesLoader.merge_with_defaults(overrides)

Rails.application.config.exemption_types = ExemptionTypesLoader.transform(merged)
```

Locale loading (Layer 2) is wired separately in `config/application.rb`, not here — see Layer 2 below.

The `ExemptionTypesLoader` module applies four hardening choices worth carrying forward as canonical for future Tier 1 concerns:

1. **`YAML.safe_load` with strictest posture.** `permitted_classes: []`, `permitted_symbols: []`, `aliases: false`. Stricter than `role_mapper.rb`'s precedent (which needs `aliases: true` for its `&default` anchors). Override files have no anchors, so `aliases: false` is appropriate and removes a YAML-bomb attack surface.
2. **`raw.is_a?(Hash)` guard before `deep_merge`.** An empty or scalar-top-level YAML would otherwise produce `NoMethodError: undefined method 'fetch' for nil` — uninformative at boot. Guarded raise produces a clear `ConfigurationError` mentioning the path. Genuinely-empty files (nil-parsing — empty file, all-comments file, or literal `{}`) are treated as "no overrides" and round-trip cleanly to `DEFAULTS`.
3. **Nested `ConfigurationError` class with diagnostic messages.** All failure paths (malformed YAML, non-Hash top-level, non-Hash entry value, missing entry field) raise `<Concern>Loader::ConfigurationError` with the path and offending id. `Psych::SyntaxError` / `Psych::DisallowedClass` are caught and re-raised as `ConfigurationError`.
4. **Per-entry validation before the pass-through merge.** `attrs.key?("enabled")` is checked before `attrs.symbolize_keys.merge(id: id.to_sym)`. Without it, a deployer's `medical_condition: {}` (mistake or partial override) would silently produce an entry with `:id` but no `:enabled`, and downstream consumers would treat it as falsy without surfacing the error.

The reference implementation lives at `reporting-app/app/services/exemption_types_loader.rb` (and its spec at `reporting-app/spec/services/exemption_types_loader_spec.rb`).

> **Note:** View and mailer override paths are wired directly in `ApplicationController` and `ApplicationMailer` by `template-application-rails` ([PR #166](https://github.com/navapbc/template-application-rails/pull/166)), not here. The OSCER-specific initializer handles only YAML config and locale loading; view path resolution comes from upstream.

**Usage in base code:**
```ruby
# Exemption types (transformed to array format; accessed via Exemption model, not ce_data)
Exemption.all        # => [{id: :caregiver_disability, enabled: true}, ...]
Exemption.enabled    # => only types where enabled: true
```

Each Tier 1 concern's merged data is wired to its own `Rails.application.config.<concern>` attribute by its initializer (e.g., `Rails.application.config.exemption_types`). Downstream consumers read these per-concern attributes rather than reaching into the loader modules directly.

**Why no env var:** OSCER deploys one instance per implementer. The earlier `ENV["STATE"]` dispatch existed to choose among customer-named subdirectories on a single instance, useful only for multi-tenant SaaS, which OSCER's product philosophy explicitly rejects (state-hosted, state-owned, state-controlled). With one config per deployment, the dispatch layer is dead weight; if a future scenario genuinely requires multi-config (A/B variants, demo showcases), it can be added back as a focused PR rather than carried preemptively.

---

## File Organization Summary

**Deployment-owned files (zero conflict):**
```
config/custom/*.yml                                      # Tier 1 domain overrides (per-concern; today: exemption_types.yml)
config/locales/overrides/**/*.yml                        # Translation overrides (deployment-owned subdirectory; loaded last via explicit application.rb plumbing)
app/views/overrides/**/*.erb                             # View and mailer template overrides
app/assets/stylesheets/_overrides.scss                   # CSS overrides (template-shipped hook, deployment fills in)
app/assets/stylesheets/custom.scss                       # Optional full alternative stylesheet
app/models/rules/custom/*.rb                             # Custom rulesets
app/services/custom/*.rb                                 # Custom services
app/models/concerns/custom/*.rb                          # Model extensions
app/models/custom/*.rb                                   # New deployment-specific models
db/migrate/*_custom_*.rb                                 # Deployment migrations (recommended naming)
```

**Base files implementers may edit (minimal conflict surface):**
```
app/services/exemption_determination_service.rb           # One-line rewire (instantiation)
app/business_processes/certification_business_process.rb  # One-line rewire (service call)
app/models/certification.rb                               # One include line (concern)
config/routes.rb                                          # New routes for deployment-specific models (append at end in a demarcated block)
```

**Base files implementers should NEVER edit:**
```
app/assets/stylesheets/_uswds-theme.scss                      # Nava's USWDS variable settings (use _overrides.scss instead)
app/views/layouts/application.html.erb                        # Use app/views/overrides/layouts/application.html.erb
app/models/*.rb (beyond concern `include` lines per Layer 5)  # Subclass or use concerns instead
app/services/*_service.rb (core logic)                        # Subclass instead
config/initializers/*.rb (except per-concern Tier 1 wirings)  # Use config/custom/ YAML override instead
config/locales/*.yml (base translations)                      # Use custom locale overrides instead
db/schema.rb                                                  # Managed by migrations
```

> **Note:** Pre-PR-#166, this spec listed `_uswds-theme.scss` and `app/views/layouts/application.html.erb` as "may edit" with one-base-file-edit conflict risk. After [`template-application-rails` PR #166](https://github.com/navapbc/template-application-rails/pull/166), both have zero-edit alternatives (`_overrides.scss` and `app/views/overrides/layouts/`), so they move to "never edit." Direct edits remain technically possible as last-resort escape hatches but should not be the recommended path.

---

## Workflow for Implementers

OSCER is published as a Copier-based Nava template (`navapbc/strata-template-oscer-app`). Implementers consume and update the template via the `nava-platform` CLI, which handles 3-way merging between the template version, the prior rendering, and the deployment's current state. See the parent strategy doc, Section 2, for the full rationale.

**Initial install:**
```bash
mkdir my-deployment && cd my-deployment && git init

# Render the OSCER template into reporting-app/
nava-platform app install \
  --template-uri https://github.com/navapbc/strata-template-oscer-app \
  --version v2026.4.0 \
  reporting-app

# (Optional) Create deployment customizations by editing the override files
# shipped under reporting-app/config/custom/. Federal-floor defaults live in
# Ruby loader modules and need no copy step. If you have no customizations,
# you can leave the override files empty or delete them entirely.
$EDITOR reporting-app/config/custom/exemption_types.yml
```

The CLI writes a committed answers file at `reporting-app/.strata-template-oscer-app/reporting-app.yml` tracking the template version and install-time answers. Updates use this file to perform 3-way merges.

**Pulling upstream updates:**
```bash
nava-platform app update reporting-app --version v2026.5.0
```

The CLI:
1. Re-renders the previous template version against the saved answers
2. Diffs that rendering against the deployment's current project (capturing local customizations)
3. Renders the new template version
4. Reapplies the divergence via a 3-way merge

**On each upstream update, implementers should:**
1. Run the `nava-platform app update`
2. Resolve conflicts in any rewired lines (for `schema.rb` conflicts, accept either version; step 4 will regenerate it)
3. Check if any overridden views have changed in base; the release changelog will flag these
4. Run migrations: `make db-migrate` (this regenerates `schema.rb` from the full migration history)
5. Run tests: `make test`

> **Known limitation:** `nava-platform`'s 3-way merge for application templates (as opposed to scaffolding templates like `template-application-rails`) is not yet well-exercised in production. PR [#501](https://github.com/navapbc/oscer/pull/501) is OSCER's own real-world experiment with the update flow. Customizations confined to the deployment-owned paths above stay disjoint from template files and are not subject to this limitation; conflicts only arise when implementers modify template files directly.

---

## What Nava Must Do to Enable This

### Phase 1: Foundation
1. Extract state-configurable policy from current Ruby initializers into per-concern loader modules under `app/services/<concern>_loader.rb`, with federal-floor defaults declared as frozen `DEFAULTS` constants inside each module
2. Ship per-concern initializers at `config/initializers/<concern>.rb` that wire each loader's optional override file under `config/custom/<concern>.yml` (no env var; view path resolution comes from upstream `template-application-rails` per PR #166)
3. Refactor code that reads from hardcoded initializers to read from `Rails.application.config.<concern>` (e.g., `Rails.application.config.exemption_types`)
4. Publish OSCER as a Copier template at `navapbc/strata-template-oscer-app` (see parent strategy doc, Section 2)
5. Gate `/demo` routes in `config/routes.rb` behind `ENV["OSCER_DEMO_MODE"]` (default unset). Production deployments leave it unset; dev and preview environments opt in.
6. Create first tagged release with changelog and migration notes

### Phase 2: Documentation & Guidance
1. Create `CUSTOMIZATION.md` with this strategy documented for implementers, including a tactical quick-reference of common file locations organized by customization task (app branding, API metadata, auth, eligibility policy, etc.)
2. Document overridable fields per Tier 1 concern in `CUSTOMIZATION.md` (each `config/custom/<concern>.yml` ships with an empty hash + inline comment block showing shape, examples, and empty-file semantics; the canonical "what can I override?" reference is each loader module's `DEFAULTS` constant)
3. Document which views are most likely to be overridden, with guidance on reconciliation
4. Add view change tracking to release changelog template

### Phase 3: Validation
1. Test the full template install-and-update workflow end-to-end with a sample deployment config
2. Verify: create deployment YAML + locale overrides + view override + subclassed ruleset, pull upstream update, confirm minimal/zero conflicts
3. Measure: what percentage of a realistic deployment customization requires base file edits?

---

## Future Improvements

The strategy above is intentionally minimal: it solves deployment customization with standard Rails patterns and no custom framework. The improvements below would reduce friction further, but each adds complexity. Introduce only when the simpler approach creates measurable pain, not preemptively.

| Improvement | What it solves | Trigger to revisit |
|---|---|---|
| **Feature Install Generators** | Multi-route, multi-controller wiring for opt-in features (e.g., `oscer:add-documentai`); deployment-owned wiring with template-owned implementation. See parent strategy doc for the broader generator framing. | First optional feature ships requiring more than env-var activation, and a deployment wants to opt in. |
| **Custom Config Registry** | Centralized dispatch via a `BaseConfig` Ruby class; replaces per-call-site rewires for rulesets, services, validators. | Deployment routinely overriding 5+ services/rulesets and tracking rewired lines becomes a maintenance burden. |
| **Custom Controller Routing** | Deployment-specific controller subclasses at fixed paths with routes auto-resolving. | Deployment needs to modify controller behavior (not just views or services) for multiple endpoints. |
| **ViewComponent Extraction** | Granular UI widget overrides instead of full-template Layer 3 swaps; deployment-specific component resolver. | Codebase independently adopts ViewComponent (for testability/reuse), or surgical widget overrides become common. (~124 ERB templates today; multi-month refactor.) |
| **View Override Staleness Detection** | CI tooling flagging when base templates overridden in `app/views/overrides/` have changed upstream. | Deployment has 10+ view overrides and changelog-checking becomes error-prone. |

The improvement below carries enough technical nuance to warrant prose, not table-row treatment.

### ApplicationRecord Auto-Include Hook (design questions unresolved)

**What:** An `inherited` hook on `ApplicationRecord` that auto-discovers and includes `Custom::{ModelName}Extensions` concern modules from a fixed path. The deployment creates concerns following the naming convention and they're automatically wired in, with zero base model edits.

**Why we deferred it:** The concern + one `include` line pattern works today with no framework. The auto-include hook has unresolved Zeitwerk discovery questions: `rescue NameError` can silently swallow real bugs in concerns, and `const_defined?` doesn't trigger autoloading. The implementation needs careful design to be reliable in both development (lazy loading) and production (eager loading).

**When to introduce:** When the deployment is extending 5+ models and the cumulative `include` lines in base models create frequent merge conflicts. Or once the auto-include mechanism is validated enough under the fixed-path convention to justify the framework investment.

---

## Open Questions

- **Deep-merge behavior with arrays:** `Hash#deep_merge` replaces arrays rather than appending. The current state-configurable surface (`exemption_types`, documentation requirements) is hash-of-hashes precisely so deep-merge stays additive between each concern's `DEFAULTS` constant and its override file. If a future Tier 1 concern's overridable surface is array-shaped, it should be modeled as a hash to preserve this property, or its loader needs explicit array-merge logic.
- **Controller customization routing:** Not yet designed. See Future Improvements section.
- **Testing strategy for custom configs:** How should implementers test their customizations? A per-concern `LoaderHelper` (e.g., `ExemptionTypesLoaderHelper`) that loads each override file and validates it against a schema would catch misconfigurations early.

---

## Key Insights from Research

- **Decidim** (closest analogue): gem extraction provides the cleanest update path, but view overrides remain the persistent pain point. Our view override approach has the same tradeoff: the deployment owns reconciliation.
- **Discourse**: Extension hook API means most customizations survive upgrades. Our subclass-and-rewire pattern achieves similar separation with less framework investment.
- **GitLab**: Required upgrade stops pattern is directly relevant for OSCER's data migrations.
- **Debian**: Patch queue model is an option for deployments with many discrete customizations (10+). Most deployments should not need this if the layered approach works.

**Success Metric:** < 5% of upstream merges have conflicts for deployments following this strategy.
