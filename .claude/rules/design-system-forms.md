# Design System: Forms

## Critical Rules

- ALWAYS use `strata_form_with` (`Strata::FormBuilder`) for ALL forms
- NEVER use `us_form_with` / `UswdsFormBuilder` for new code (legacy, auth pages only)
- NEVER use raw `form_with` — always use a USWDS-aware builder
- ALWAYS use `t()` for ALL user-visible text (labels, hints, buttons, legends)
- Forms auto-apply `usa-form usa-form--large` classes

## Basic Form Invocation

```erb
<%# Model-backed form %>
<%= strata_form_with(model: @model) do |f| %>
  <%= f.text_field :name, label: t(".name") %>
  <%= f.submit t(".save"), big: true %>
<% end %>

<%# Nested resource %>
<%= strata_form_with(model: [@parent, @child]) do |f| %>

<%# Custom URL/method %>
<%= strata_form_with(url: some_path, method: :post) do |f| %>

<%# With Stimulus controller and Turbo disabled %>
<%= strata_form_with(url: path, data: { turbo: false, controller: "my-controller" }) do |f| %>
```

## Field Method Reference

### Text Inputs

```erb
f.text_field :attr, label: t(".label"), hint: t(".hint")
f.text_field :attr, label: t(".label"), width: "md"        # usa-input--md width
f.email_field :attr, label: t(".label")
f.password_field :attr, label: t(".label")
f.text_area :attr, label: t(".label")
f.file_field :attr, label: t(".label")
f.file_field :attr, label: t(".label"), multiple: true
```

Width options: `"2xs"`, `"xs"`, `"sm"`, `"md"`, `"lg"`, `"xl"`, `"2xl"`

### Toggle Inputs

```erb
<%# Radio button (tile style by default) %>
f.radio_button :attr, "value", { label: t(".label"), tile: true }
f.radio_button :attr, "value", { label: t(".label"), tile: false }  # non-tile
f.radio_button :attr, "value", {
  label: t(".label"),
  hint: "Description text",
  tile: true,
  data: { action: "change->my-controller#someAction" }
}

<%# Checkbox (tile style by default) %>
f.check_box :attr, { label: t(".label") }
```

### Select

```erb
f.select :attr, options_array, { prompt: t(".prompt") }
f.select :attr, options_array, { label: t(".label") }, { autocomplete: "off" }
```

### Composite Fields (Strata-only)

```erb
f.yes_no :attr, { legend: t(".legend") }
f.yes_no :attr, { legend: t(".legend"), yes_options: { label: "Custom Yes" } }

f.date_picker :attr                              # single date with USWDS date picker
f.date_range :attr                               # start + end date pickers in fieldset
f.memorable_date :attr                           # month select + day/year inputs

f.tax_id_field :attr                             # masked SSN/TIN (123-45-6789)
f.money_field :attr, label: t(".label")          # dollar amount, decimal inputmode
f.name :attr                                     # first, middle, last, suffix fields
f.address_fields :attr                           # street (2 lines), city, state, zip
```

### Structure & Layout

```erb
f.fieldset t(".legend") do
  <%# grouped fields here %>
end

f.fieldset t(".legend"), { large_legend: true, attribute: :attr } do
  <%# fields with error support %>
end

f.hidden_field :attr, value: "some_value"
f.honeypot_field                                 # anti-spam hidden field

f.submit t(".save")                              # usa-button
f.submit t(".continue"), big: true               # usa-button usa-button--big
f.submit t(".save"), class: "usa-button--outline" # outline variant
```

### Conditional Fields

Show/hide content based on a radio button value:

```erb
<%# Using Strata's conditional helper %>
<%= f.conditional :my_radio_attr, eq: "yes" do %>
  <%= f.text_field :follow_up, label: t(".follow_up") %>
<% end %>

<%# With clear: true to reset hidden inputs %>
<%= f.conditional :status, eq: ["active", "pending"], clear: true do %>
  <%# shown when status is "active" or "pending" %>
<% end %>
```

## Error Display

- **Inline errors**: FormBuilder auto-wraps fields with `usa-form-group--error` and renders `usa-error-message` spans
- **Fieldset-level errors**: Use `f.field_error :attr` for explicit error display
- **Flash errors**: Use `AlertComponent` in `_flash.html.erb` partial

```erb
<%# Flash error pattern %>
<%= render AlertComponent.new(type: :error, heading: t("flash.error_heading", count: errors.count)) do |c| %>
  <% c.with_body do %>
    <ul class="usa-list">
      <% errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  <% end %>
<% end %>
```

## Accessibility

- Labels: Auto-generated via `usa-label` class, linked via `for` attribute
- Hints: Auto-linked via `aria-describedby` pointing to hint element ID
- Errors: `usa-error-message` rendered between label and input
- Fieldsets: Use `usa-fieldset` with `usa-legend` for grouped inputs (radio groups, date parts)
- Required: Fields are required by default; add `optional: true` for optional fields
- Screen readers: Use `usa-sr-only` class for visually hidden but accessible labels
