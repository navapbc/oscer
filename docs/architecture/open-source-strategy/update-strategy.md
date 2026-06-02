# OSCER Open Source Update Strategy: Technical Recommendations

**Issue:** [#213](https://github.com/navapbc/oscer/issues/213)
**Date:** 2026-04-01 (last updated 2026-05-20)
**Author:** Michael Giver
**Status:** Living document — published to the OSCER repo via [#620](https://github.com/navapbc/oscer/issues/620); updated as implementation evolves

---

## Executive Summary

OSCER should be published as a **Copier-based Nava template** (`navapbc/strata-template-oscer-app`), consumed and updated by implementers via the `nava-platform` CLI. The full monorepo is the wrong unit of adoption. Deployments won't use Nava's `infra/`, `.github/`, or `e2e/` configuration, and forking the full repo means merging upstream changes to infrastructure that's been completely replaced. The template approach solves the update-with-divergence problem directly via Copier's 3-way merge and keeps OSCER consistent with the rest of the Nava template ecosystem (see Section 2).

Most variance between deployments belongs in **configuration**, not code. OSCER's working-assumptions doc (`docs/hr1-working-assumptions.md`) commits to keeping state-configurable policy open to each deployment: exemption list composition and documentation requirements. Federally-opinionated rules (calendar-month reporting, hours-or-income non-combinability, medically-frail breadth) stay opinionated in Ruby. The current code has an implementation gap where state-configurable policy is hardcoded in Ruby initializers. Closing that gap is the Phase 2 priority (Section 7).

A four-tier customization ladder (config → locales and branding → generators → extension points) keeps deployment-owned customization disjoint from template-owned files so Copier updates don't conflict. Tier 4 is backed by an explicit **Extension Contract** (Section 5) defining OSCER's stable surface: paths, event names, public signatures. Internals outside the contract may change between releases. Monthly stable releases plus ad-hoc security patches ship through `nava-platform app update`.

---

## 1. Current State Analysis

### What OSCER's architecture enables today

**Low-friction customization (env/config only, no code changes):**
- Authentication providers: adapter pattern (`Auth::CognitoAdapter`, `Auth::MockAdapter`) plus env vars (`AUTH_ADAPTER`, `SSO_*`, `MEMBER_OIDC_*`)
- Storage backends: `STORAGE_ADAPTER` env var selects S3/Azure/GCP
- Feature flags: registry in `config/initializers/feature_flags.rb`, env-var driven
- Branding/CSS: USWDS theme overrides in SCSS
- SSO role mapping: `config/sso_role_mapping.yml` per environment
- Email routing: env-var driven (AWS SES)

**Moderate-friction customization (config files that may conflict on merge):**
- Locale files: 36 files across `config/locales/`, new translations can be added but existing keys may diverge
- SSO role mapping: implementers will customize IdP group → role mappings
- Environment-specific Rails configs: `config/environments/`

### Key coupling points

| Area | Files affected | Risk |
|------|---------------|------|
| Strata SDK | ~45 Ruby files (models, policies, forms, helpers, business processes, views) | HIGH. No pinned version, API changes ripple |
| Migrations | 52 files, some mix data + schema changes | HIGH. Forked deployments adding columns will conflict |
| Exemption/activity config | 1 initializer + 1 model module | HIGH. Implementers will customize domain categories |
| Infrastructure | 100+ Terraform files | VERY HIGH. Every deployment has different AWS setup |
| Locale files | 36 files | MODERATE. High churn, additive changes can conflict |

### What varies between deployments

Deployments differ along three axes: operations (config-driven today), domain policy (partially config, partially hardcoded), and infrastructure (complete replacement per deployment).

**Operations: config-driven today**

| Concern | Mechanism |
|---|---|
| Auth provider (Cognito, Azure AD, Okta) | `AUTH_ADAPTER` env var |
| Storage backend (S3, Azure Blob, GCP) | `STORAGE_ADAPTER` env var |
| Feature toggles | `FEATURE_*` env vars |
| UI copy, branding, translations | YAML locale files (36 files) |
| SSO role mapping | `config/sso_role_mapping.yml` |

The adapter pattern and env-var conventions cover operations cleanly. No gap.

**Domain policy: partially hardcoded**

Some domain concerns are hardcoded in Ruby today where they should be deployment-configurable:

| Concern | Current code | Note |
|---|---|---|
| Exemption list composition (categories beyond the federal floor) | Hardcoded in `config/initializers/exemption_types.rb` | `hr1-working-assumptions.md` explicitly states *"Exemption categories are state-configurable... OSCER does not hardcode a single national exemption list"* |
| Exemption documentation requirements (attestation vs. document-verified) | No config switch; handled in the Ruby application flow | `hr1-working-assumptions.md` notes this is *"a state-level policy decision, not an OSCER default"* |

These are **implementation gaps**. Phase 2 addresses them.

**Federally-opinionated rules.** OSCER takes policy positions on rules that reflect CMS guidance interpretation rather than state policy variance. A deployment should not customize these; implementers who think one needs to change should bring it upstream as a policy discussion, not fork. Section 4's "What you should NOT customize" subsection enumerates the current working list, grounded in `docs/hr1-working-assumptions.md`.

**Infrastructure.** Different axis. Every deployment has entirely different AWS setup (100+ Terraform files). Remains code-level customization via complete replacement, not a sharing concern.

**Key finding:** The hardcoding of state-configurable policy is an **implementation gap between the current code and the design intent**, not a structural constraint requiring fork-based customization. Closing the gap (extracting exemption list composition and documentation requirements to YAML) is the near-term priority (Phase 2, Section 7). The Section 4 customization ladder and Section 5 Extension Contract together keep deployment-owned work disjoint from template-owned files; see the companion [customize-and-extend doc](./customize-and-extend.md) for implementation detail.

---

## 2. Repository Strategy: Copier Template

### Problem: the monorepo is the wrong unit of adoption

The OSCER monorepo contains `reporting-app/`, `infra/`, `e2e/`, `.github/`, and `docs/`. Deployments won't use Nava's `infra/` (100+ Terraform files for Nava-specific AWS accounts, VPCs, Cognito pools, domains). Forking the full monorepo means every upstream merge includes changes to infrastructure that's been completely replaced; guaranteed conflicts on irrelevant files.

### Solution: publish OSCER as a Copier template

OSCER should be published as a Copier-based Nava template (`navapbc/strata-template-oscer-app`), consumed and updated by implementers via the `nava-platform` CLI. This aligns OSCER with the existing Nava template ecosystem; implementers using `template-infra` or `template-application-rails` work with the same CLI and the same mental model.

The Copier template model solves the update-with-divergence problem directly. When an implementer updates a deployment to a new OSCER release, the CLI:
1. Re-renders the previous template version against the project's saved answers
2. Diffs that rendering against the deployment's current project (capturing local customizations)
3. Renders the new template version
4. Reapplies the divergence via a 3-way merge

This is better suited to "consume an opinionated application, customize locally, pull upstream improvements" than subtree or fork workflows, which rely on generic git merging without awareness of template-versus-customization. (That awareness lives in a committed answers file, e.g. `.strata-template-oscer-app/reporting-app.yml`, which tracks the template version and answers across updates.)

**Existing precedent.** `navapbc/strata-template-documentai-api` is a Copier template for a complete application, not just scaffolding. Its README frames it as *"more of a complete application intended for use almost out of the box"* (the same shape OSCER would take), and its `copier.yml` exposes just two install-time variables (`app_name`, `app_local_port`). OSCER would follow the same pattern: deployment-configurable policy lives in YAML config files inside the rendered project (extracted from Ruby during Phase 2; see Section 7), not as additional Copier install-time parameters.

### Known limitation: application-template conflicts

Application-template conflicts are a known limitation of `platform-cli`, not a blocker; OSCER's adoption may help mature this part of the CLI. `platform-cli`'s `avoiding-conflicts-on-update.md` explicitly notes *"No good advice at the moment"* for application-template conflict resolution. The CLI's test harness exercises three scaffolding templates (`template-application-rails`, `-flask`, `-nextjs`): install once, diverge heavily. It does not exercise DocumentAI or any application-shaped template. Real-world experience with updating a heavily-customized application template is not well-established. In practice, this limitation primarily affects customizations made directly in template files; customizations confined to dedicated extension-point locations stay disjoint from OSCER's templates and are not subject to it.

### Pending confirmation

OSCER development should flip to `strata-template-oscer-app` as the primary dev repo, following the DocumentAI pattern, where the template is where development happens and the monorepo becomes a reference implementation instantiated from the published template. Cross-cutting changes spanning both `reporting-app/` and `infra/` have been rare in practice (≈3% of app-touching merges over the past 5+ months), so the two-repo friction cost of the flip is absorbable. Final decision pending team alignment.

---

## 3. Use Case 1: Deploying As-Is (No Customization)

**Scenario:** An implementer deploys OSCER without modifications. They want to pull in updates cleanly.

### Recommended approach: Tagged releases + `nava-platform app update`

**Release process:**
1. Nava cuts tagged releases on a regular cadence (recommend monthly, with ad-hoc security releases)
2. Each release includes:
   - Git tag on `navapbc/strata-template-oscer-app` (see versioning section below)
   - GitHub Release with changelog (auto-generated from PRs + manual curation for policy/security flags)
   - Migration notes: what DB migrations are included, whether data migrations exist
   - Breaking change flags: anything that changes config, env vars, or API contracts
   - Minimum Strata SDK version required

**Install workflow (first-time setup):**
```bash
# Inside the deployment's project (already initialized with template-infra)
nava-platform app install \
  --template-uri gh:navapbc/strata-template-oscer-app \
  --commit . reporting-app

cd reporting-app && make db-migrate && make test
```

For implementers starting a brand-new project, see the [`nava-platform` new-project guide](https://github.com/navapbc/platform-cli/blob/main/docs/getting-started/new-project.md) for the full `infra install` → `app install` sequence.

**Update workflow:**

Review the release notes for migration requirements and breaking changes before running the update.

```bash
# Update to the latest tagged release
nava-platform app update . reporting-app

# Apply any new migrations and verify
cd reporting-app && make db-migrate && make test
```

To target a specific version instead of the latest: `nava-platform app update --version v2026.5.0 . reporting-app`.

With no customizations, the update is effectively a re-render at the new template version. Copier preserves the deployment's saved answers (app name, port) in the committed answers file (e.g. `.strata-template-oscer-app/reporting-app.yml`) and refreshes template-owned files to the new version. See Section 2 for the update mechanism in detail.

> **Note:** `nava-platform app update` requires a clean working tree (no uncommitted changes). A common pattern is to run updates in a dedicated git worktree or a separate clean clone. See [`platform-cli` updating docs](https://github.com/navapbc/platform-cli/blob/main/docs/updating.md) for details.

### Automated update detection (recommended)

Nava should publish a GitHub Action implementers can add to their repos to automate update detection. The Action watches `navapbc/strata-template-oscer-app` for new tagged releases and opens a PR against the deployment's repo when an update is available, giving implementer teams a Dependabot-style experience where template updates arrive as PRs ready for review. For implementers customizing only within dedicated extension-point locations (see Section 4), the update PR is typically a clean merge.

The Action targets GitHub-hosted deployment projects. Implementers on other source-control platforms can adapt the same pattern (scheduled check, `nava-platform app update`, merge/pull request) to their own CI system, or run `nava-platform app update` manually on their preferred cadence.

**Tooling to build:**
- GitHub Actions workflow that notifies deployment repos when a new OSCER release is published (via repository dispatch or webhook)
- Release template in `.github/RELEASE_TEMPLATE.md` ensuring consistent changelog format

**Notification channels:**
- GitHub Releases on `navapbc/strata-template-oscer-app` (implementers watch the repo)
- Mailing list (mentioned in governance doc, TBD)
- Policy-critical and security-critical releases get explicit callouts

---

## 4. Use Case 2: Deploying with Customizations

**Scenario:** An implementer deploys OSCER with deployment-specific customizations: branding, translations, state-configurable policy (see Section 1), and possibly modular features they've opted into or out of. They want to maintain those customizations while pulling upstream updates.

This is the expected primary use case. The customization ladder below is ordered from simplest to most involved, with each tier designed to minimize merge conflicts by keeping deployment-owned work separate from template-owned files. Tier-specific implementation examples live in the companion [customize-and-extend doc](./customize-and-extend.md).

### Customization ladder

| Tier | Mechanism | Conflict risk | When to use |
|---|---|---|---|
| 1 | Config (YAML + feature flag env vars) | Zero | State-configurable policy and runtime toggles |
| 2 | Locales + branding (SCSS, custom assets) | Zero to low | UI copy, visual theming, deployment-specific terminology |
| 3 | Generators (proposed, not implemented today; see Section 7 Phase 3) | Low | Modular feature installation (e.g., DocAI) when flag-off isn't enough |
| 4 | Extension points (see Section 5: Extension Contract) | Zero within contract | Behavioral variance where config alone isn't enough |

**Tier 1: Config (YAML + feature flags).** Implementers adjust state-configurable policy via YAML config files (e.g., exemption category set above the federal floor, attestation-vs-documentation policy) and toggle runtime behavior via feature flag environment variables. Both are zero-conflict because they're data implementers own, not code they edit.

**Tier 2: Locales + branding.** Implementers override UI strings via locale files and visual theming via SCSS or custom assets. Zero to low conflict: locale and asset files live in deployment-owned paths, disjoint from template-owned files. View-level overrides are Tier 4 territory; see Section 5's Extension Contract.

**Tier 3: Generators.** For modular features an implementer wants to install selectively (or not install at all), OSCER proposes a generator pattern (see next subsection). Not implemented today. Examples of features that fit this tier: DocAI, SSO adapters, VA integration (modular integrations where an implementer wants explicit control over whether the feature's wiring is present in their project at all, rather than just toggled off at runtime).

**Tier 4: Extension points.** For behavioral variance that config alone can't express (and for view-level layout and template overrides), implementers modify dedicated extension-point locations that OSCER guarantees to keep stable. See **Section 5: Extension Contract** for the definition of which paths are extension points and what stability commitments OSCER makes.

**If the ladder doesn't cover your case:** an implementer can stop pulling upstream updates and maintain their project independently. This is outside the customization ladder; it's not a mechanism within OSCER but a decision to leave OSCER's update path. Features, security fixes, and policy updates will no longer arrive automatically; the implementer takes full responsibility going forward. Implementers considering this path should discuss with Nava first; in practice, most needs can be met at Tiers 1-4 or by proposing an addition to the Extension Contract (see Section 5).

### Generator pattern: how it works

**The generator pattern is proposed for OSCER, not implemented today** (see Section 7 Phase 3). Using DocAI as a worked example of what it *could* look like:

- **Generator creates (deployment-owned, rendered once):** a config initializer, any required migrations, and a route mount for the feature's endpoints
- **Template provides (template-owned, updates via Copier):** the feature's models, services, jobs, controllers, and views (the full implementation)
- **Update semantics:** Copier updates deliver new versions of the feature; deployment-owned wiring stays in place unless the DSL changes (treated like a gem upgrade with release-notes guidance)

This matches how Devise and similar Rails gems already work: `rails g devise:install` creates a deployment-owned initializer; the Devise implementation ships in the gem and updates via `bundle update`. The key distinction from feature flags: flags gate *behavior* (feature loaded, conditionally active); generators gate *presence* (feature's wiring only exists if installed). Both can coexist: a feature can be generator-installed AND flag-gated. See Section 8 for the three-way split of modular integrations, runtime toggles, and rollout controls.

### What you should NOT customize

Some rules in OSCER reflect CMS guidance interpretation, not state policy variance. Examples of the kinds of rules that are federally opinionated: reporting period definitions, compliance pathway structures, exemption criteria, and activity category definitions. Changing them in a fork means the deployment is no longer meeting the federal requirement.

**For the current working list of federally-opinionated rules, see `docs/hr1-working-assumptions.md`**, OSCER's working interpretation of H.R. 1 statute in the absence of complete CMS rulemaking, not exhaustively reproduced here. Both the doc and this classification are expected to shift as the interim final rule (due 2026-06-01) and subsequent CMS guidance are issued.

**If an implementer believes they need to change one of these:** raise the question with the OSCER policy/product team for discussion. These rules may legitimately evolve if federal guidance changes, but they should change for every deployment, not a single deployment's fork.

### Update workflow

The update flow is the same whether or not the deployment has customizations: `nava-platform app update . reporting-app`, then migrations and test (see Section 3 for the full command reference and clean-working-tree requirement). The difference is that customized deployments may encounter Copier 3-way-merge conflicts on template-owned files the implementer has edited (the limitation flagged in Section 2's Known Limitation paragraph). Implementers customizing within Tier 1-4 locations minimize this conflict risk by design: those tiers use deployment-owned files or extension-point contracts that stay disjoint from template-owned files.

### Merge-conflict tooling (rare-case footnote)

For implementers who edit template-owned files beyond the extension-point contract, `git rerere` (reuse recorded resolution) can cache conflict resolutions for repeating patterns. The Debian patch queue model (maintaining customizations as a documented, ordered patch series, with `gbp pq rebase` to forward-port patches onto new upstream versions) is another option for deployments with many discrete divergences. Both are rare-case tools, not recommended approaches; implementers staying within Tiers 1-4 should not need them.

---

## 5. Extension Contract

The Extension Contract defines OSCER's **stable surface** (paths, signatures, and payloads deployments can depend on across releases) and what is explicitly **unstable**. Implementers modifying within the contract get predictable updates: extension-point locations stay disjoint from template-owned files, so Copier updates at those paths are no-ops. The contract is what makes the customization ladder's Tier 4 (Section 4) a zero-conflict tier.

### 5.1 Extension-point locations

The contract covers the locations in the table below, plus public API endpoints, environment variable names, YAML config schemas (`config/sso_role_mapping.yml` today; per-concern override schemas under `config/custom/*.yml` after the Phase 1 extraction shipped via [#540](https://github.com/navapbc/oscer/issues/540) / PR [#564](https://github.com/navapbc/oscer/pull/564) — today: `config/custom/exemption_types.yml`), Strata event names and payload shapes, and public service/ruleset signatures, all subject to the versioning policy in Section 6. All mechanisms are Rails-native; OSCER does not introduce additional extension-point plumbing.

| #   | Path                                                          | Purpose                                         | Mechanism                                                                                                                             | Status                                                                                                                                                                                                                           |
| --- | ------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `app/assets/stylesheets/_overrides.scss`                      | SCSS additions on top of OSCER + USWDS defaults | `@forward "overrides"` is the last forward in `application.scss`, so overrides win by source order                                    | Shipped via [PR #522](https://github.com/navapbc/oscer/pull/522) (merged 2026-05-01); template source [`template-application-rails` PR #166](https://github.com/navapbc/template-application-rails/pull/166) (merged 2026-04-30) |
| 2   | `app/assets/stylesheets/custom.scss` (builds to `custom.css`) | Full stylesheet replacement                     | Separate asset build; requires overriding `app/views/layouts/application_base.html.erb` to link `"custom"` instead of `"application"` | Shipped via [PR #522](https://github.com/navapbc/oscer/pull/522); heaviest of the SCSS-level extensions                                                                                                                          |
| 3   | `app/views/overrides/<path>/`                                 | View template overrides at matching subpaths    | `prepend_view_path` on `ActionView::FileSystemResolver.new("app/views/overrides")` in `ApplicationController` class body              | Shipped via [PR #522](https://github.com/navapbc/oscer/pull/522)                                                                                                                                                                 |
| 4   | `config/locales/**`                                           | UI copy and translations                        | Rails-native locale load path                                                                                                         | Uses today's locale directory structure                                                                                                                                                                                          |

**Implementer-facing reference.** [`docs/how-to-guides/branding.md`](https://github.com/navapbc/oscer/blob/main/docs/how-to-guides/branding.md) (shipped via [PR #522](https://github.com/navapbc/oscer/pull/522)) is the how-to for SCSS, view, and mailer overrides (rows 1-3 above). Locale customization (row 4) follows Rails-native conventions — implementers add files under `config/locales/**` mirroring OSCER core's directory layout, and Rails' I18n load path picks them up automatically. Overriding existing keys requires explicit load-order management in the implementer's initializer; consider documenting the recommended pattern in `branding.md` or a follow-up how-to.

### 5.2 What changes beneath the contract

Two non-obvious distinctions about what the contract does **not** promise:

- **View override granularity.** The outer template an implementer overrides in `app/views/overrides/` is stable; OSCER commits to keeping the path and the template's rendering responsibilities unchanged. How OSCER internally composes that template with sub-partials (`render partial: …`) is not stable; partial names, argument shapes, and presence may change between releases. Overrides should stay as close as possible to the original template (see `branding.md` best practices) to limit exposure when internal composition shifts.
- **Migration file names and ordering aren't stable.** A deployment owns its data, not OSCER's migration history. When forking beyond the contract (see 5.3) or customizing schema, the deployment's migration sequence can diverge; the contract is that the resulting database state is recoverable, not that the migration file names match.

### 5.3 When the contract doesn't cover your case

Implementers with a customization need that 5.1's extension points cannot express can fall back to **Pattern A**: edit template-owned files directly and rely on Copier's 3-way merge at update time. This accepts the limitation from Section 2. `platform-cli`'s `avoiding-conflicts-on-update.md` flags application-template conflict resolution as an open area (*"no good advice at the moment"*).

Pattern A should be a rare-case escape hatch, not a first resort. Implementers hitting this limit should propose a new extension point upstream so every deployment benefits.

---

## 6. Versioning & Release Strategy

### Recommended: Calendar Versioning (CalVer)

**Format:** `YYYY.N.P`
- `YYYY`: year
- `N`: release number within the year (sequential, not month)
- `P`: patch number (security fixes, critical bugs)

**Example:** `2026.3.0` → third release of 2026, initial version. `2026.3.1` → patch to that release.

**Why CalVer over SemVer:**
- SemVer's "breaking change" concept is fuzzy for deployed applications (vs. libraries with programmatic APIs)
- CalVer communicates release recency at a glance
- Discourse adopted CalVer for exactly these reasons
- OSCER's API layer could independently use SemVer for the `/api/` contract (via OpenAPI spec versioning)

### Release channels

| Channel | Cadence | Audience | Branch/tag |
|---------|---------|----------|------------|
| **Latest** | Every merge to `main` | Nava development, CI | `main` branch |
| **Stable** | Monthly, plus ad-hoc patches | All deployments | `v2026.N.P` tags |

Patch releases (`v2026.N.P` where P > 0) ship between monthly releases for security-critical and urgent bug fixes.

### Required upgrade stops

Following GitLab's pattern, document **required stop versions** where:
- Complex data migrations must complete before proceeding
- Strata SDK version bumps introduce breaking changes
- Database schema changes require specific migration ordering
- Breaking changes to the Extension Contract (Section 5)

Example: "Implementers upgrading from `2026.1.x` to `2026.4.x` must first upgrade to `2026.2.0` and run migrations."

---

## 7. Implementation Roadmap

### Phase 1: Enable first adoption

Minimum viable deliverable for an implementer to install OSCER via `nava-platform app install` and begin customizing.

| Ticket | Description | Impact |
|--------|-------------|--------|
| Create `strata-template-oscer-app` repo | Initial Copier template scaffolding with `copier.yml` (`app_name` + `app_local_port` + `deployment_namespace`), `template/{{app_name}}/` subdirectory, and a README covering install + basic customization orientation. Migration uses `git filter-repo` to preserve `reporting-app/` commit history, with paths rewritten to `template/{{app_name}}/`. Includes `_skip_if_exists` configuration covering the Tier 1 override surface file-by-file (today: `config/custom/exemption_types.yml`; each future Tier 1 concern added explicitly) plus the two SCSS hook files (`_overrides.scss`, `custom.scss`), and Jinja-fication of the Layer 4/5 scaffold directories to use the `deployment_namespace` parameter. | Enables `nava-platform app install` to target a real template; bakes the namespace-customization parameter in from v1 so post-release retrofit is avoided |
| Set up Tier 1 and Tier 2 customization infrastructure | Replace the original hardcoded Ruby exemption-types initializer with a code-defaults + optional YAML override pattern: federal-floor defaults live in `ExemptionTypesLoader::DEFAULTS` (frozen Ruby constant inside a per-concern loader module at `app/services/exemption_types_loader.rb`); deployment override at `config/custom/exemption_types.yml` is optional and deep-merged at boot. Per-concern split scales naturally as Tier 1 grows (next planned: `documentation_requirements.yml`). Add `config/locales/overrides/` directory with explicit two-step `I18n.load_path` plumbing in `config/application.rb` so override files load after all base locale files. | Closes the implementation gap between the working-assumptions doc (state-configurable exemption lists) and the hardcoded implementation; gives deployments zero-conflict locale overrides via Rails-native conventions. Load-bearing for first-implementer adoption (promoted from Phase 2 2026-05-12; restructured per peer review 2026-05-20 — Jeff Dettmann). |
| Ship Layer 4/5 customization hook scaffolds | Ship empty deployment-owned directories (`app/services/custom/`, `app/models/custom/`, `app/models/concerns/custom/`, `app/models/rules/custom/`, `app/views/overrides/`) with `.keep` and discoverability `README.md` files. Harmonized layout: all four Ruby customization paths use the same `custom/` subdirectory pattern; `Rules::Custom::ExemptionRuleset`-style namespacing replaces the earlier `custom_*.rb` filename-prefix design for consistency with services, models, and concerns. Adds a regression-guard spec that `ApplicationController.view_paths` and `ApplicationMailer.view_paths` include `app/views/overrides/` (the directory itself shipped earlier via PR #522). | Implementers find drop-in locations on first directory listing rather than needing to read `CUSTOMIZATION.md` first; mirrors the discoverability-README pattern PR #564 established for Tier 2 |
| Create first tagged release | Establish the `v2026.N.0` tag with a Release template scaffolded for future changelog consistency (features, fixes, policy-critical, security, migration notes). Verifies `deployment_namespace` parameter is in `copier.yml` before tagging so v1 ships the parameter rather than retrofitting later. | Enables implementers to track versions and adopt a specific one |
| `CUSTOMIZATION.md` | Tier 1-4 guidance from Section 4 plus a tactical quick-reference of file locations organized by customization task (app branding, locales, eligibility policy, view overrides, custom services + models). Includes a "Picking your deployment namespace" prelude documenting the `copier.yml` parameter, a "What survives `nava-platform app update`" section documenting `_skip_if_exists` mechanics, and a "When you need something off-ladder" section pointing implementers at the upstream-issue feedback loop. | Gives implementers an actionable Day-1 customization guide with explicit boundaries between deployment-owned, template-owned, and update-preserved files |

(Note: "Pin Strata SDK to tagged releases" was originally listed here. Closed 2026-05-12 by decision — Gemfile.lock pinning protects deploys; tagged Strata releases would be signal-only and can be revisited if implementer-visible failure modes emerge.)

### Phase 2: Close the implementation-vs-design gap + release hygiene

Release-process hardening that accrues value once a release cadence exists, plus the layered-template architecture that lets Rails-platform improvements flow into OSCER deployments.

(Note: "Extract state-configurable policy to YAML" was promoted from Phase 2 to Phase 1 on 2026-05-12 per team discussion — exemption-list customization is load-bearing for first-implementer adoption rather than a post-adoption ergonomic improvement. See Phase 1.)

| Ticket | Description | Impact |
|--------|-------------|--------|
| Keep migrations simple and separable | Audit existing migrations, establish convention: no mixed schema + data migrations, reversible where possible, no app-model-class references inside migrations, document when required upgrade stops apply. Document the install path (`db:schema:load` + `db:seed`) vs update path (`db:migrate`) distinction. | Cleaner upgrade path for deployments with customizations or large datasets; narrows migration-replay-safety to the update path |
| Upgrade `strata-template-oscer-app` to be a `template-application-rails` consumer | Make `strata-template-oscer-app` a Copier consumer of `template-application-rails` (two-hop inheritance chain). Requires an upstream `app_name` validator-relaxation PR, a bootstrap answers file, and a `_exclude` directive for the layered-architecture state directory. | Rails-platform improvements flow into OSCER deployments via `nava-platform app update`; closes the "no Rails-platform tracking" gap from Phase 1's one-time extraction |
| Flip primary dev to template repo | Move day-to-day OSCER development to `strata-template-oscer-app` (Section 2's DocumentAI pattern); the monorepo becomes a reference render for demo + dogfooding. Sequenced after the layered-consumer upgrade so the template inherits Rails-platform updates rather than stagnating. | Closes the dev-workflow decision; validates the implementer install-and-update workflow end-to-end |
| Pre-publish CI check on template repo | GitHub Actions workflows on `strata-template-oscer-app` that (a) on every template PR, open or update a corresponding PR in a downstream test-consumer repo (the OSCER monorepo) with rendered output, and (b) on push to template `main`, push the render to the consumer. Modeled on `template-application-rails ↔ navapbc/platform-test`. Preview-environment and infra-integration validation lives downstream in the test-consumer's CI. | Prevents broken-on-fresh-install templates from reaching implementers |
| Document release subscription paths | Documentation-only ticket. "How to subscribe to releases" section in CUSTOMIZATION.md + template-repo README, pointing implementers at the GitHub Releases page + Watch-the-repo subscription path. No notification infrastructure built — `template-application-rails` ships releases with no notification system beyond GitHub Releases and there is no documented failure mode yet. Broader notification surface (broadcast venues, automated workflows, cross-repo dispatch) deferred to follow-ups gated on implementer demand. | Implementers can find and subscribe to releases without Nava-side infrastructure investment |

### Phase 3: Extension points + ergonomic tooling

Convenience layers and Extension Contract formalization.

| Ticket | Description | Impact |
|--------|-------------|--------|
| Formalize event-hook documentation | Document `Strata::EventManager` event names and payload shapes as the stable surface committed to in Section 5.1 | Implementers can subscribe to events with an explicit contract rather than reading OSCER's internals |
| API versioning strategy | Implement `/api/v1/` prefix and OpenAPI spec pinning | API consumers can adopt OSCER versions independently of their integration code |
| Deployment guide | Document how to wire existing Nava infra templates ([template-infra](https://github.com/navapbc/template-infra), [template-infra-azure](https://github.com/navapbc/template-infra-azure)) with OSCER, including required env vars, role mapping, and config setup | Reduces onboarding friction for new deployments |
| Publish `oscer-update-action` reusable GitHub Action | Convenience layer on top of `nava-platform app update` that watches the template repo for new tags and opens a PR in the deployment's repo. Not required for the update flow; manual CLI runs are always an option | Gives implementers a Dependabot-style experience for template updates |
| Cross-repo preview env on template PRs | Template-repo CI triggers a downstream test-consumer PR (per the Phase 2 layering); the consumer's preview-environment deployment posts back to the originating template PR via GitHub Deployment status, giving reviewers a clickable URL for user-testing template changes that affect rendered HTML/CSS | Visual/UX changes to the template are reviewable in a real browser before merging — CI test results catch logic regressions; deployment status catches rendered-output regressions |

**Generator implementation deferred.** The generator pattern described in Section 4 (Tier 3) is Phase 3+ work, implemented when an implementer surfaces a concrete need that feature flags can't meet. The most likely first candidate is DocAI when an implementer wants code-level separation rather than runtime disablement.

**Future direction: modular/component adoption.** If a deployment eventually wants only parts of OSCER (e.g., just the exemption screener or batch upload system), the bounded contexts could be extracted into separate Rails engines/gems following the Decidim model. The Strata SDK is already a separate gem, which is the right foundation. This is a significant refactoring effort and not a near-term priority, but design decisions now (clean bounded contexts, minimal cross-domain coupling, config-driven customization) make future extraction feasible. See the [customize-and-extend doc](./customize-and-extend.md) Future Improvements section for more detail.

---

## 8. Open Questions (from ticket; need team/leadership input)

| Question | Context | Suggested answer |
|----------|---------|-----------------|
| **Ruby upgrades for deployments?** | Ruby 3.4.7 currently; feature versions release annually each December (patch releases are more frequent) | No. Document the required Ruby version per OSCER release. Deployments are responsible for their runtime. The monthly Stable cadence (Section 6) gives implementers room to plan Ruby bumps alongside OSCER version bumps. |
| **Security vulnerability responsibility?** | Who patches, who discloses, who is liable? | Nava patches OSCER core and publishes security releases as ad-hoc patch tags between monthly releases (Section 6). Implementers are responsible for applying them to their deployments. Existing `SECURITY.md` and vulnerability management docs cover disclosure. |
| **New features not everyone wants or that don't fit every deployment?** | Feature divergence across deployments | Three-layer split: **generators** control whether a feature is *installed* (deployment-owned wiring in, implementation in the template; Section 4 Tier 3); **feature flags** control whether an installed feature is *active* at runtime per environment (Section 4 Tier 1); **config** (YAML) controls *how* a feature behaves where state-configurable policy applies (same tier, different mechanism). Long-term, engine extraction (Decidim model) makes modular adoption cleaner. |
| **Company strategy implications?** | This affects Nava's business model and implementer relationships | The update strategy should be reviewed with leadership before publishing. Key question: is Nava's value proposition "we maintain the upstream" or "we do the updates for you"? This affects whether we invest in self-service tooling vs. managed update services. |
| **How do others do it?** | Comparable projects | Decidim (gem extraction), Discourse (plugin hooks + ESR), GitLab (required upgrade stops) are the most applicable models. |

