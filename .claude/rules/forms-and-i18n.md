# Forms and Internationalization

## USWDS forms

Use `us_form_with` instead of `form_with` for all views. It applies USWDS styling automatically:

```erb
<%= us_form_with model: @form do |f| %>
  <%= f.text_field :name, { hint: t(".name.hint") } %>
  <%= f.yes_no :has_previous_leave %>
  <%= f.fieldset t(".type_legend") do %>
    <%= f.radio_button :type, "medical" %>
  <% end %>
  <%= f.submit %>
<% end %>
```

## Internationalization

- Locales: English and Spanish (`es-US`)
- Routes are localized via `route_translator`
- All user-facing strings must go in `config/locales/`
- View-specific keys use nested paths matching the view file path
- Generate locale files: `make locale`
