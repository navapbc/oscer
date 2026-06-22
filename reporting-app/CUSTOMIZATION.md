# Customizing your OSCER deployment

This is the Day-1 guide for tailoring an OSCER deployment: branding, copy,
eligibility policy, and deployment-specific behavior. It maps the most common
customization tasks to the supported mechanism that does the job, ordered from
lowest to highest friction (and conflict risk when you sync upstream OSCER
changes), and to the exact files you edit.

Use the lowest-friction mechanism that does the job. Config and locale/branding
overrides are zero-conflict data and content you own; extension points are code
against stable seams. Staying with these supported mechanisms is what keeps
upstream syncs clean.

> OSCER is the upstream open-source platform. A deployment maintains its own
> downstream repo and periodically syncs upstream OSCER changes into it. Tagged
> releases are tracked in [#531](https://github.com/navapbc/oscer/issues/531)
> (epic [#527](https://github.com/navapbc/oscer/issues/527)); until the first
> release, deployments sync from `main`.
>
> Deployment-extension code lives under the `Custom::` namespace (the `custom/`
> directories shown in the examples below).

## Supported customization mechanisms

| Mechanism | Conflict risk | Use for |
|---|---|---|
| Config (YAML + `FEATURE_*` env vars) | None | State-configurable policy, runtime toggles |
| Locales + branding (SCSS, custom assets) | None–low | UI copy, theming, deployment terminology |
| Extension points (code) | None within the Extension Contract | Behavior config alone can't express |

## Config

State-configurable policy and runtime toggles: data you own, no code edits.

**Exemption types.** Federal-floor defaults are OSCER-owned and declared in
code (`ExemptionTypesLoader::DEFAULTS` in
`app/services/exemption_types_loader.rb`); that constant is the canonical "what
can I override?" reference. Your overrides go in `config/custom/exemption_types.yml`
and are deep-merged over the defaults; declare only what differs:

```yaml
# config/custom/exemption_types.yml
medical_condition:
  enabled: false          # disable a default exemption type
disaster_evacuation:
  enabled: true           # add a deployment-specific one
```

The override file is optional: leave it empty or delete it for no overrides.
Deployment-owned config under `config/custom/` is a file OSCER rarely edits, so
your overrides stay conflict-free across syncs (see [Keeping upstream syncs
clean](#keeping-upstream-syncs-clean)).

**Runtime toggles.** `FEATURE_*` environment variables turn features on/off per
environment (see `config/initializers/feature_flags.rb`).

## Locales and branding

**Copy and terminology.** Drop YAML files under `config/locales/overrides/`;
they load after all base locales, so your keys win on conflict. Renaming the
program (e.g. "CommunityCare" → your program's name) is a locale change, not a
config setting.

```yaml
# config/locales/overrides/views/application/my-state.en.yml
en:
  views:
    application:
      title: "MyState Community Engagement Reporting"
```

See [`config/locales/overrides/README.md`](config/locales/overrides/README.md)
for layout conventions.

**Visual theming.** Add styles to `app/assets/stylesheets/_overrides.scss`
(cascades after USWDS, so it wins) for most branding: colors, fonts, logo,
spacing. Use `app/assets/stylesheets/custom.scss` only when you need to replace
the whole stylesheet. Full how-to (CSS, view, and mailer branding):
[`docs/how-to-guides/branding.md`](https://github.com/navapbc/oscer/blob/main/docs/how-to-guides/branding.md).

## Extension points

For behavior config alone can't express. These are stable seams: the paths below
are part of OSCER's **Extension Contract**: the set of paths OSCER guarantees
stay disjoint from OSCER-owned files, so files you add here don't conflict when
you sync upstream. The contract covers the **paths**; how OSCER internally
composes a view from sub-partials is **not** stable; keep overrides close to
the original to limit exposure.

### View and mailer overrides

Mirror a view's path under `app/views/overrides/` and it wins via
`prepend_view_path` (wired in `ApplicationController` and `ApplicationMailer`).
Same mechanism for mailer templates.

```
app/views/overrides/certifications/show.html.erb     # overrides the cert show page
app/views/overrides/member_mailer/exempt_email.html.erb
```

Security-critical templates (Devise sessions/MFA, CSRF-bearing forms) silently
win when overridden. Preserve auth, CSRF tokens, and MFA prompts. Details:
[`app/views/overrides/README.md`](app/views/overrides/README.md) and
[`branding.md`](https://github.com/navapbc/oscer/blob/main/docs/how-to-guides/branding.md).

### Service and ruleset subclassing

Subclass the base service/ruleset under your namespace, then rewire the one line
that instantiates it.

```ruby
# app/services/custom/exemption_determination_service.rb
module Custom
  class ExemptionDeterminationService < ::ExemptionDeterminationService
    # deployment-specific overrides
  end
end
```

Note OSCER's services are flat (no `Services::` namespace), so the parent is
`::ExemptionDeterminationService`. Rulesets go in `app/models/rules/custom/`
under `Rules::Custom::`. Deployments may **add** exemptions but must not narrow
the federally-required ones (disability, pregnancy, Native American / Alaska
Native, age). Details:
[`app/services/custom/README.md`](app/services/custom/README.md),
[`app/models/rules/custom/README.md`](app/models/rules/custom/README.md).

### Model extension

Add fields with a migration (Rails discovers new columns automatically). Add
validations, scopes, or methods via a concern + one `include` line; add new
models under your namespace.

```ruby
# app/models/concerns/custom/certification_extensions.rb
module Custom
  module CertificationExtensions
    extend ActiveSupport::Concern
    included { validates :county, presence: true }
  end
end

# app/models/certification.rb, deployment adds one line:
include Custom::CertificationExtensions
```

New models exposed to controllers also need a Pundit policy
(`make new-authz-policy MODEL=...`). Details:
[`app/models/concerns/custom/README.md`](app/models/concerns/custom/README.md),
[`app/models/custom/README.md`](app/models/custom/README.md).

## Quick reference

| I want to… | Mechanism | Where |
|---|---|---|
| Change logo, colors, fonts | Locales + branding | `app/assets/stylesheets/_overrides.scss` (or `custom.scss`) |
| Rename the program / change member-facing copy | Locales + branding | `config/locales/overrides/` |
| Override an email template | Branding / extension points | `branding.md` (mailer view) or `app/views/overrides/member_mailer/` |
| Adjust the exemption list | Config | `config/custom/exemption_types.yml` |
| Toggle a feature on/off | Config | `FEATURE_*` env var |
| Override a view partial or layout | Extension points | `app/views/overrides/` |
| Override determination logic / call an external service | Extension points | `app/services/custom/` |
| Add a custom eligibility rule | Extension points | `app/models/rules/custom/` |
| Add fields/scopes to an existing model | Extension points | `app/models/concerns/custom/` |
| Add a deployment-specific model | Extension points | `app/models/custom/` (+ migration, + policy) |

## Keeping upstream syncs clean

You keep current by syncing upstream OSCER changes into your deployment. Three
categories of files determine whether that stays clean:

1. **Files you add in the namespace and override directories**:
   `app/services/custom/`, `app/models/custom/`, `app/models/rules/custom/`,
   `app/models/concerns/custom/`, `app/views/overrides/`, and
   `config/locales/overrides/`. These are new files OSCER never ships, so a sync
   never overwrites them. Always clean.
2. **Deployment-owned config and branding hooks**: `config/custom/*.yml` and
   the SCSS hooks (`_overrides.scss`, `custom.scss`). OSCER ships these as empty
   or starter files and rarely edits them, so your edits survive a sync in
   practice. If a future upstream change does touch one, you re-apply your edit
   the next time you sync.
3. **OSCER-owned files everywhere else**: base views, models, services, and the
   `README.md`/`.keep` files in the directories above. Editing these in place
   means re-applying your change on every sync that also touches them.

The principle: every customization routed through an override directory or a
deployment-owned config file is a file upstream never edits, so a sync leaves it
untouched. Customizations made by editing OSCER-owned files in place are what
generate sync work, which is exactly what the override mechanisms above let you
avoid.

## When a mechanism can't express your need

If a customization need can't be met by the supported mechanisms above, **file
an upstream issue** rather than editing an OSCER-owned file directly. Filing an
issue is how the set of supported mechanisms grows; we'd rather know about an
unmet need than discover it through a divergent downstream. If the team agrees, the
next release adds the seam and your customization becomes supported.

## Related docs

- [Branding how-to](https://github.com/navapbc/oscer/blob/main/docs/how-to-guides/branding.md): SCSS, view, and mailer overrides
