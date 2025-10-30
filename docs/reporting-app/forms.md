# Forms

A custom `us_form_with` helper is provided to create forms. This adds the necessary U.S. Web Design System classes to the form and its elements, as well as simplifies the creation of labels, hint text, and inline error messages.

The `us_form_with` helper is a drop-in replacement for the standard `form_with` helper. It accepts the same arguments and options as `form_with`, and exposes the same [field helpers](https://guides.rubyonrails.org/form_helpers.html).

Example usage:

```erb
<%= us_form_with model: @claim do |f| %>
  <%= f.text_field :name, { hint: t(".name.hint") } %>

  <%= f.fieldset t("claim_types.legend") do %>
    <%= f.radio_button :claim_type, "medical" %>
    <%= f.radio_button :claim_type, "family" %>
  <% end %>

  <%= f.submit %>
<% end %>
```

## Labels

When using the `us_form_with` helper, you don't need to use a separate `label` helper. Instead, you can pass a `label` option to the field helper:

```erb
<%= f.text_field :name, { label: "Full name" } %>
```

## Hint text

You can add hint text to a field by passing a `hint` option to the field helper:

```erb
<%= f.text_field :name, { hint: "Enter your full name" } %>
```

To include hint text within a fieldset, use the `hint` helper:

```erb
<%= f.fieldset "Notification preferences" do %>
  <%= f.hint "Select the ways you'd like to be notified" %>
```

## Fieldsets

Use the custom `fieldset` helper to create a fieldset with a legend, rather than the standard `field_set_tag` helper.

```erb
<%= f.fieldset "Notification preferences" do %>
  <%= f.check_box :email %>
  <%= f.check_box :sms %>
<% end %>
```

Use `field_error` to display an error message for a radio group:

```erb
<%= f.fieldset "Plan" do %>
  <%= f.field_error :plan %>
  <%= f.radio_button :plan, "health" %>
  <%= f.radio_button :plan, "medical" %>
<% end %>
```

A `human_name` helper is provided to format a field name for display to the user. This is primarily useful for fieldset legends – other fields already utilize this behind the scenes.

```erb
<%= f.fieldset f.human_name(:notification_preferences) do %>
  <%= f.check_box :email %>
  <%= f.check_box :sms %>
<% end %>
```

## Yes/No fields

Use the custom `yes_no` helper to create a pair of radio buttons for a boolean field:

```erb
<%= f.yes_no :has_previous_leave %>
```

To apply custom labels or hint text to the radio buttons, pass in `yes_options` and `no_options`:

```erb
<%= f.yes_no :has_previous_leave, {
  yes_options: { label: "Yes, I've taken leave before" },
  no_options: { label: "No, I haven't taken leave before" }
} %>
```

## Text inputs

Control the width of a text input by passing a `width` option to the field helper, with a value corresponding to the `width` values accepted by [the `usa-input--[width]` class](https://designsystem.digital.gov/components/text-input/#using-the-text-input-component-2).

```erb
<%= f.text_field :name, { width: "md" } %>
```

## Testing

When running the app locally, a test form is available at `/dev/sandbox`
