# View and Mailer Overrides

Holds override versions of templates shipped by OSCER. Files here win over
their template-shipped counterparts via `prepend_view_path` (wired in
`ApplicationController` and `ApplicationMailer`).

## Example

Override the certification show page by mirroring its path:

    # app/views/overrides/certifications/show.html.erb

Override a mailer template the same way:

    # app/views/overrides/member_mailer/welcome.html.erb

For the full pattern, see CUSTOMIZATION.md.

## Ownership

`.erb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
