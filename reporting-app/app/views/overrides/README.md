# View and Mailer Overrides

Holds override versions of templates shipped by OSCER. Files here win over
their template-shipped counterparts via `prepend_view_path` (wired in
`ApplicationController` and `ApplicationMailer`).

## Example

Override the certification show page by mirroring its path:

    # app/views/overrides/certifications/show.html.erb

Override a mailer template the same way:

    # app/views/overrides/member_mailer/exempt_email.html.erb

## Override with care

Security-critical templates (Devise sessions/MFA, destructive-action
confirmations, CSRF-bearing forms) silently win when overridden. Preserve
auth, CSRF tokens, and MFA prompts in any override you ship.

For the full pattern, see CUSTOMIZATION.md (Extension points — View and
mailer overrides).

## Ownership

The `.erb` overrides you add here are deployment-owned. This `README.md` and
`.keep` are maintained upstream by OSCER; leave them unedited so syncing
upstream changes stays conflict-free.
