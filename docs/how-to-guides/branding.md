# How to brand OSCER

This guide explains how to customize the look and feel of the OSCER user experience.

## Cascading Style Sheets (CSS)

OSCER uses the cssbundling-rails gem to bundle its stylesheets. Add css styles to `app/assets/stylesheets/_overrides.scss`, and these styles will automatically be used.

## Views

OSCER uses ERB for its view templates. When looking for which template to render, it first searches `app/views/overrides/**`, then searches `app/views/**`. OSCER core uses the views in `app/views/**`, but you can override a template in these views by copying it to an identical subdirectory in `app/views/overrides/`.

For example, if you wanted to override the home page, whose template is `app/views/home/index.html.erb`, you would copy it to `app/views/overrides/home/index.html.erb` and make modifications there.

## Best Practices

1. Do not modify any OSCER core files.
2. When overriding a template, try to keep it as close as possible to the OSCER core version. Only change what you need to get the look and feel you want. Some parts of the template might be necessary for the proper user experience, and you don't want to accidentally remove them.