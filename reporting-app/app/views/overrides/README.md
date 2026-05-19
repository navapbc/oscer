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

For the full pattern, see CUSTOMIZATION.md "Layer 4: View and Mailer
Overrides" (in progress:
[#539](https://github.com/navapbc/oscer/issues/539)).

## Ownership

`.erb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
