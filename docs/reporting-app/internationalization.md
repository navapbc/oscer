# Internationalization

We use Rails' built-in internationalization (i18n) to support multiple languages, [read the general documentation here](https://guides.rubyonrails.org/i18n.html).

To create new locale files for a model and/or its views, you can run:

```sh
make locale MODEL=MyModel
```

## Organization of locale files

Placing translations for all parts of an application in one file per locale can become hard to manage. We've chosen to organize our translations into multiple YAML files, using the following hierarchy

- `defaults` - fallback errors, date, and time formats
- `models` - model and attribute names
- `views` - strings specifically rendered in views, partials, or layouts

> [!CAUTION]
> Be aware that YAML interprets the following case-insensitive strings as booleans: `true`, `false`, `on`, `off`, `yes`, `no`. Therefore, these strings must be quoted to be interpreted as strings. For example: `"yes": yup` and `enabled: "ON"`

## Routes and links

The active locale is based on the URL. For example, to use the Spanish locale, visit: `/es-US`.

When adding a new route, ensure it's nested within the `localized` block so that it can be viewed at the appropriate locale.

To ensure links preserve the locale, it's important for them to include the locale param, which happens automatically when using `link_to` or `url_for` helpers:

```erb
<%= link_to "Apply", controller: "claims", action: "new" %>
```

## Rendering content

To render content, use `I18n.t`:

```ruby
I18n.t("hello")
```

In views, this is aliased to just `t`:

```erb
<%= t("hello") %>
```

### Dates

To format dates, use the custom `local_time` helper:

```erb
<%= local_time(foo.created_at) %>
```

To include the time, use the `:format` option:

```erb
<%= local_time(foo.created_at, format: :long) %>
```

## Adding a new language

1. Add new YAML file(s) in `config/locales`
1. Update `available_locales` in `config/application.rb` to include the new locale
