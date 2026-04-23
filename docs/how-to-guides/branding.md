# How to brand OSCER

This guide explains how to customize the look and feel of the OSCER user experience.

## Cascading Style Sheets (CSS)

OSCER uses the cssbundling-rails gem to bundle its stylesheets. For simple changes, add CSS styles to `app/assets/stylesheets/_overrides.scss`, and these styles will automatically be used.

To override all styles; for example, to change USWDS default colors; build a custom stylesheet by updating `app/assets/stylesheets/custom.scss`. You will also need to override the application_base layout template to link to this "custom" stylesheet rather than OSCER's "application" stylesheet. To use the "custom" stylesheet, copy `app/views/layouts/application_base.html.erb` to `app/views/overrides/layouts/application_base.html.erb` and update the "stylesheet_link_tag" to use "custom" instead of "application". See `app/assets/stylesheets/demo_theme.scss` and `app/views/demo_theme/layouts/application_base.html.erb` for an example of this process.

## Views

OSCER uses ERB for its view templates. When looking for which template to render, the application first searches `app/views/overrides/**`, then searches `app/views/**`. OSCER core uses the views in `app/views/**`, but you can override a view template by copying it to an identical subdirectory in `app/views/overrides/`.

For example, if you wanted to override the home page, whose template is `app/views/home/index.html.erb`, you would copy it to `app/views/overrides/home/index.html.erb` and make modifications there.

See `app/views/demo_theme/**` for an example of overriding view templates.

## Best Practices

- Add new files instead of modifying OSCER core files. Feel free to modify `app/assets/stylesheets/_overrides.scss` and `app/assets/stylesheets/custom.scss`, but add new files in the `app/views/overrides` and `app/assets/stylesheets` directories to brand your implementation of OSCER.
- When overriding a template, try to keep it as close as possible to the OSCER core version. Only change what you need to get the look and feel you want. Some parts of the template that seem extraneous might be necessary for the proper user experience.