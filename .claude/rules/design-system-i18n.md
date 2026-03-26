# Design System: Internationalization (i18n)

## Critical Rules

- ALWAYS use `t()` for ALL user-visible text — NEVER hardcode English strings
- App supports `en` and `es-US` locales — both must have translations
- Use **lazy lookup** `t(".key")` in views (auto-scoped to view path)
- Use **full path** `t("namespace.key")` in helpers, controllers, and mailers

## Locale File Organization

```
config/locales/
├── defaults/          ← Shared: errors, date/time formats, common strings
│   ├── en.yml
│   └── es-US.yml
├── models/            ← Model names and attribute names
│   ├── en.yml
│   └── es-US.yml
├── views/             ← View-specific text (one file per controller)
│   ├── activities/
│   │   ├── en.yml
│   │   └── es-US.yml
│   ├── certification_cases/
│   │   ├── en.yml
│   │   └── es-US.yml
│   └── ...
├── services/          ← Service-layer text (mailers, notifications)
├── devise.en.yml      ← Devise auth messages
└── exemption_types.en.yml ← Exemption type configuration
```

## Key Naming Conventions

```yaml
# Views: match the controller/action path
en:
  activities:
    form:                    # partial: _form.html.erb
      title_prefix: "Add a"
      name: "Activity name"
      select_prompt: "Select a month"
      continue: "Save and continue"
    show:                    # action: show
      title: "Activity Details"

# Models: under activerecord.models and activerecord.attributes
en:
  activerecord:
    models:
      activity: "Activity"
    attributes:
      activity:
        name: "Activity name"
        month: "Reporting month"
```

## Common Patterns

```erb
<%# Page title %>
<% content_for :title, t(".title") %>

<%# Form labels and hints %>
f.text_field :name, label: t(".name"), hint: t(".name_hint")

<%# Button text %>
f.submit t(".save")
f.submit t(".continue"), big: true

<%# Interpolation %>
<%= t(".greeting", first_name: @user.first_name) %>

<%# Pluralization %>
<%= t("flash.error_heading", count: @errors.count) %>
<%# en.yml: error_heading: { one: "1 error", other: "%{count} errors" } %>

<%# Date formatting %>
<%= l(date, format: :local_en_us) %>    <%# MM/DD/YYYY %>
<%= local_time(time, format: :long) %>  <%# with timezone %>

<%# Flash messages %>
flash[:notice] = t(".success_message")
flash[:errors] = t(".error_message")
```

## YAML Gotchas

- Always **quote** values that are YAML booleans: `"true"`, `"false"`, `"yes"`, `"no"`, `"on"`, `"off"`
- Use `%{variable}` for interpolation placeholders
- Nested keys match the view path hierarchy

## Figma Text → i18n Keys

When translating Figma text content to code:
1. Create an i18n key using the lazy lookup convention: `t(".descriptive_key")`
2. Add the English text to `config/locales/views/{controller}/en.yml`
3. Add a placeholder or translation to the corresponding `es-US.yml`
4. NEVER leave hardcoded strings in ERB templates
