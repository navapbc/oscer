# How to brand OSCER

This guide explains how to customize the look and feel of the OSCER user experience.

## Cascading Style Sheets (CSS)

OSCER uses the cssbundling-rails gem to bundle its stylesheets. Branding cascades
after USWDS, so your rules win. Three SCSS hooks let you scope a change to one
surface or both:

| Hook | Applies to | Builds into | Loaded by |
|---|---|---|---|
| `app/assets/stylesheets/_overrides.scss` | **Both** client and staff | `application.css` | every layout |
| `app/assets/stylesheets/_client_overrides.scss` | **Client only** (member-facing) | `client.css` | `layouts/application_base` (after `application`) |
| `app/assets/stylesheets/_staff_overrides.scss` | **Staff only** | `staff.css` | `layouts/oscer_staff` (after `application`, via `:head`) |

Use the narrowest hook that expresses the change: a client-only restyle goes in
`_client_overrides.scss`, staff-only in `_staff_overrides.scss`, and genuinely
app-wide branding (shared brand color, logo) in `_overrides.scss`.

To override all styles; for example, to change USWDS default colors; build a
custom stylesheet by updating `app/assets/stylesheets/custom.scss`. You will
also need to override the application_base layout template to link to this
"custom" stylesheet rather than OSCER's "application" stylesheet. To use the
"custom" stylesheet, copy `app/views/layouts/application_base.html.erb` to
`app/views/overrides/layouts/application_base.html.erb` and update the
shared `stylesheet_link_tag` to use `"custom"` instead of `"application"`.

**Keep the `stylesheet_link_tag "client"` that follows it** so client-only
hooks in `_client_overrides.scss` still apply. If you override the staff layout
(`layouts/oscer_staff` or `layouts/strata/staff`), **keep loading `staff.css`
after the shared/custom bundle** (via `:head` or an explicit link) so
staff-only hooks still apply. Note: `custom.scss` is a **shared** full-reskin
hatch across both surfaces unless you maintain separate layout overrides and
keep those surface bundles linked.

## Views

OSCER uses ERB for its view templates. When looking for which template to render, the application first searches `app/views/overrides/**`, then searches `app/views/**`. OSCER core uses the views in `app/views/**`, but you can override a view template by copying it to an identical subdirectory in `app/views/overrides/`.

For example, if you wanted to override the home page, whose template is `app/views/home/index.html.erb`, you would copy it to `app/views/overrides/home/index.html.erb` and make modifications there.

## Mail templates

Mail templates follow the same logic as web page templates.

For example, to remove the demo notice from the member emails, you would create blank files at `app/views/overrides/member_mailer/_demo_notice.html.erb` and `app/views/overrides/member_mailer/_demo_notice.text.erb`.


## Best Practices

- Add new files instead of modifying OSCER core files. Feel free to modify the SCSS hooks (`_overrides.scss`, `_client_overrides.scss`, `_staff_overrides.scss`, and `custom.scss`), but add new files in the `app/views/overrides` and `app/assets/stylesheets` directories to brand your implementation of OSCER.
- Prefer surface-scoped hooks (`_client_overrides.scss` / `_staff_overrides.scss`) over `_overrides.scss` when a change should not affect both UIs.
- When overriding a template, try to keep it as close as possible to the OSCER core version. Only change what you need to get the look and feel you want. Some parts of the template that seem extraneous might be necessary for the proper user experience — including the `client` / `staff` stylesheet links described above.
