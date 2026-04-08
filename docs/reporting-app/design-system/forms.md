# OSCER Design System: Forms

Complete reference for building USWDS-compliant forms in the OSCER reporting application. All forms use the Strata SDK's `FormBuilder`, which wraps the [U.S. Web Design System (USWDS) form controls](https://designsystem.digital.gov/components/form-controls/) with Rails conventions for labels, hints, errors, and accessibility.

---

## Table of contents

- [Choosing a form builder](#choosing-a-form-builder)
- [Basic form invocation](#basic-form-invocation)
- [Field method reference](#field-method-reference)
  - [Text inputs](#text-inputs)
  - [Toggle inputs (radio buttons and checkboxes)](#toggle-inputs-radio-buttons-and-checkboxes)
  - [Select dropdowns](#select-dropdowns)
  - [Composite fields (Strata-only)](#composite-fields-strata-only)
  - [Structure and layout](#structure-and-layout)
  - [Conditional fields](#conditional-fields)
  - [Submit buttons](#submit-buttons)
- [Error handling](#error-handling)
- [Accessibility](#accessibility)
- [Migration from us_form_with](#migration-from-us_form_with)
- [USWDS documentation links](#uswds-documentation-links)

---

## Choosing a form builder

OSCER has two form builders. **Always use `strata_form_with` for new code.**

| Builder | Helper | Class | Status |
|---|---|---|---|
| **Strata** | `strata_form_with` | `Strata::FormBuilder` | **Active** -- use for all new forms |
| **Legacy** | `us_form_with` | `UswdsFormBuilder` | **Deprecated** -- auth pages only |

### Why Strata over the legacy builder

`Strata::FormBuilder` (defined in `strata-sdk-rails/app/helpers/strata/form_builder.rb`) is a superset of `UswdsFormBuilder` (defined in `reporting-app/app/helpers/uswds_form_builder.rb`). Both extend `ActionView::Helpers::FormBuilder` and auto-apply `usa-form usa-form--large` classes to the `<form>` element. The key differences:

1. **Additional composite field methods** -- Strata provides `name`, `address_fields`, `memorable_date`, `money_field`, `date_range`, and `conditional`, none of which exist in the legacy builder.
2. **Better error handling** -- Strata's `fieldset` renders `field_error` automatically when an `attribute:` is provided. The legacy builder requires manual error rendering in fieldsets.
3. **Fieldset improvements** -- Strata adds `margin-top-0` to legend classes and supports `hint` as a fieldset option, while the legacy builder does not.
4. **`form_group_id` generation** -- Strata generates stable IDs for form groups (`#{field_id(attribute)}_form_group`), enabling JavaScript targeting and anchor links to error fields.
5. **`skip_form_group` support** -- Strata's text input overrides accept `skip_form_group: true` to render label + input without a wrapping `usa-form-group` div, which is needed inside composite fields like `money_field` and `memorable_date`.
6. **Radio button tile default** -- Strata defaults `tile: true` on radio buttons and lets you opt out with `tile: false`. The legacy builder always applies tile styling with no opt-out.
7. **ConditionalFieldComponent integration** -- `f.conditional` renders a `Strata::ConditionalFieldComponent` with Stimulus-based show/hide behavior and optional input clearing.

### When you might still see `us_form_with`

The legacy builder is used on authentication pages (login, registration) that were built before the Strata SDK was integrated. Do not migrate these unless explicitly planned -- they work correctly and have their own test coverage. All other forms should use `strata_form_with`.

---

## Basic form invocation

### Model-backed form

The most common pattern. Rails infers the URL and HTTP method from the model.

```erb
<%= strata_form_with(model: @model) do |f| %>
  <%= f.text_field :name, label: t(".name") %>
  <%= f.submit t(".save"), big: true %>
<% end %>
```

### Nested resource

When the model is a child of another resource, pass an array. Rails generates the correct nested route (e.g., `/activity_report_application_forms/:id/activities`).

```erb
<%= strata_form_with(model: [activity_report_application_form, activity.becomes(Activity)]) do |f| %>
  <%= f.text_field :name, label: t(".name") %>
  <%= f.submit t(".continue"), big: true %>
<% end %>
```

The `.becomes(Activity)` call is an STI pattern -- it tells Rails to use the `Activity` base class for route generation even when the object is a subclass like `HourlyActivity`.

### Custom URL and method

When you need explicit control over the form action:

```erb
<%= strata_form_with(url: some_path, method: :post) do |f| %>
  <%= f.text_field :query, label: t(".search") %>
  <%= f.submit t(".go") %>
<% end %>
```

### Stimulus controller and Turbo options

Pass `data:` to attach Stimulus controllers or disable Turbo Drive:

```erb
<%= strata_form_with(
    url: exemption_screener_answer_question_path(
      exemption_type: @current_exemption_type,
      certification_case_id: @certification_case.id
    ),
    method: :post,
    data: { turbo: false, controller: "exemption-screener" }
  ) do |f| %>
  <%# form fields %>
<% end %>
```

Setting `turbo: false` causes a full page navigation on submit instead of a Turbo Drive fetch. This is useful for forms that redirect to a different domain or need a full page reload.

### Delete form (inline)

For destructive actions, use `method: :delete` and style the submit as a secondary button:

```erb
<%= strata_form_with(
    model: [@activity_report_application_form, @activity.becomes(Activity)],
    method: :delete,
    html: { class: "display-inline-block" }
  ) do |f| %>
  <%= f.submit t(".delete"), class: "usa-button--secondary" %>
<% end %>
```

---

## Field method reference

All field methods accept an `attribute` symbol as the first argument. The attribute name is used to:

1. Read the current value from the model object (`object.send(attribute)`)
2. Generate the HTML `name` attribute (e.g., `model[attribute]`)
3. Generate the HTML `id` attribute (e.g., `model_attribute`)
4. Look up validation errors (`object.errors[attribute]`)
5. Look up the human-readable label via `object.class.human_attribute_name(attribute)` when no `label:` is provided

### Text inputs

These methods override the standard Rails form helpers to wrap them in USWDS markup with automatic label, hint, and error rendering.

#### `text_field`

```erb
f.text_field :name, label: t(".name")
f.text_field :name, label: t(".name"), hint: t(".name_hint")
f.text_field :ssn, label: t(".ssn"), width: "md"
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Model attribute name |
| `label:` | String | `human_attribute_name` | Label text. Always use `t()` for i18n. |
| `hint:` | String/Proc | `nil` | Hint text rendered below the label. Can be a string or a Proc that returns HTML. |
| `width:` | String | `nil` | Input width class. Maps to `usa-input--#{width}`. Options: `"2xs"`, `"xs"`, `"sm"`, `"md"`, `"lg"`, `"xl"`, `"2xl"` |
| `label_class:` | String | `""` | Additional CSS classes for the label element |
| `skip_form_group:` | Boolean | `false` | If true, renders label + input without the wrapping `usa-form-group` div. Used internally by composite fields. |
| `optional:` | Boolean | `false` | If true, appends "(optional)" hint text to the label |
| `group_options:` | Hash | `{}` | Additional HTML attributes for the wrapping `usa-form-group` div |

**Generated HTML structure:**

```html
<div class="usa-form-group" id="model_name_form_group">
  <label class="usa-label" for="model_name">Name</label>
  <!-- error span appears here if validation fails -->
  <div class="usa-hint" id="name_hint">Hint text</div>
  <input class="usa-input" type="text" name="model[name]" id="model_name" />
</div>
```

#### `email_field`

Identical API to `text_field`. Renders `<input type="email">`.

```erb
f.email_field :email, label: t(".email")
```

#### `password_field`

Identical API to `text_field`. Renders `<input type="password">`.

```erb
f.password_field :password, label: t(".password")
```

#### `text_area`

Identical API to `text_field`. Renders `<textarea>` with `usa-textarea` class.

```erb
f.text_area :notes, label: t(".notes")
```

#### `file_field`

Renders a USWDS-styled file upload input.

```erb
f.file_field :document, label: t(".upload_document")
f.file_field :documents, label: t(".upload_documents"), multiple: true
```

**Parameters (in addition to standard text_field params):**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `multiple:` | Boolean | `false` | Allow multiple file selection |

### Toggle inputs (radio buttons and checkboxes)

#### `radio_button`

Renders a USWDS radio button. **Tile style is enabled by default** in the Strata builder.

```erb
f.radio_button :answer, "yes", {
  label: t(".buttons.yes_answer"),
  hint: @current_question["yes_answer"],
  tile: true,
  data: { action: "change->exemption-screener#enableSubmit" }
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Model attribute name |
| `tag_value` | String | required | The value submitted when this radio is selected |
| `label:` | String | `human_attribute_name` | Label text |
| `hint:` | String | `nil` | Description text rendered below the label inside the tile |
| `tile:` | Boolean | `true` | Whether to render as a USWDS tile radio. Set `false` for compact radios. |
| `data:` | Hash | `nil` | Data attributes, commonly used for Stimulus actions |

**Generated HTML structure (tile style):**

```html
<div class="usa-radio">
  <input class="usa-radio__input usa-radio__input--tile" type="radio"
         name="model[answer]" id="model_answer_yes" value="yes" />
  <label class="usa-radio__label" for="model_answer_yes">
    Yes
    <span class="usa-radio__label-description">Description text</span>
  </label>
</div>
```

**Real-world example** from `exemption_screener/show.html.erb`:

```erb
<%= strata_form_with(
    url: exemption_screener_answer_question_path(
      exemption_type: @current_exemption_type,
      certification_case_id: @certification_case.id
    ),
    method: :post,
    data: { turbo: false, controller: "exemption-screener" }
  ) do |f| %>

  <fieldset class="usa-fieldset">
    <legend class="usa-sr-only">
      <%= @current_question["question"] %>
    </legend>

    <%= f.radio_button :answer, "yes", {
      label: t(".buttons.yes_answer"),
      hint: @current_question["yes_answer"],
      tile: true,
      data: { action: "change->exemption-screener#enableSubmit" }
    } %>

    <%= f.radio_button :answer, "no", {
      label: t(".buttons.no_answer"),
      tile: true,
      data: { action: "change->exemption-screener#enableSubmit" }
    } %>

    <%= f.submit t(".buttons.submit"),
        class: "usa-button",
        data: { exemption_screener_target: "submit" } %>
  </fieldset>
<% end %>
```

#### `check_box`

Renders a USWDS checkbox. Always rendered with tile styling.

```erb
f.check_box :pregnancy_status
f.check_box :agree_to_terms, { label: t(".agree") }
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Model attribute name |
| `label:` | String | `human_attribute_name` | Label text |
| Additional args | varies | | Standard Rails `check_box` args (checked_value, unchecked_value) |

**Multi-value checkbox pattern:**

When using `check_box` with a `checked_value` argument (for multi-select scenarios), the builder generates the correct label `for` attribute using `field_id(attribute, checked_value)`.

### Select dropdowns

```erb
f.select :month,
  month_select_options(activity_report_application_form.reporting_period_dates),
  { prompt: t(".select_prompt") }
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Model attribute name |
| `choices` | Array | required | Array of `[label, value]` pairs or flat array of values |
| `options` | Hash | `{}` | Rails select options: `prompt:`, `label:`, `include_blank:`, `selected:`, `skip_form_group:` |
| `html_options` | Hash | `{}` | HTML attributes for the `<select>` element: `autocomplete:`, `disabled:`, `class:` |

**Examples:**

```erb
<%# Basic select with prompt %>
f.select :region, @regions, { prompt: t(".select_region") }

<%# Select with label and html options %>
f.select :state, us_states_list,
  { label: t(".state") },
  { autocomplete: "address-level1" }

<%# Select with mapped options and disabled state %>
f.select :lookback_period,
  options.map { |i| [t("options.#{i}"), i] },
  {},
  disabled: @form.locked_type_params?

<%# Select with include_blank for optional fields %>
f.select :race_ethnicity, race_options, { include_blank: true }
```

### Composite fields (Strata-only)

These methods are only available in `Strata::FormBuilder` and do not exist in the legacy `UswdsFormBuilder`. They render multi-input field groups that map to complex data types.

#### `yes_no`

Renders a yes/no radio button pair with a hidden field for blank submissions.

```erb
f.yes_no :is_eligible, { legend: t(".eligibility_question") }
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Boolean attribute name |
| `legend:` | String | `human_attribute_name` | Fieldset legend text |
| `yes_options:` | Hash | `{ label: "Yes" }` | Options passed to the "yes" radio button |
| `no_options:` | Hash | `{ label: "No" }` | Options passed to the "no" radio button |

**How it works:** Renders a hidden field with an empty value (so the attribute is always submitted), a `<fieldset>` with the legend, and two radio buttons for `true` and `false`. The Strata i18n keys `strata.form_builder.boolean_true` and `strata.form_builder.boolean_false` provide the default labels.

#### `date_picker`

Renders a USWDS date picker with a text input and calendar widget.

```erb
f.date_picker :certification_date
f.date_picker :start_date, label: t(".start_date"), hint: t(".date_hint")
```

**Parameters:** Accepts the same options as `text_field` (including `label:`, `hint:`, `width:`). Additionally:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `group_options:` | Hash | `{}` | Passed to the wrapping `usa-date-picker` div |

**How it works:** Reads the current value from the model. If the value is a `Date`, it formats it as `MM/DD/YYYY` for display and sets `data-default-value` as `YYYY-MM-DD` for the USWDS JavaScript widget. Automatically appends a format hint ("mm/dd/yyyy").

See: [USWDS Date Picker](https://designsystem.digital.gov/components/date-picker/)

#### `date_range`

Renders a start date and end date picker inside a fieldset.

```erb
f.date_range :reporting_period, legend: t(".reporting_period")
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Base attribute name. Generates `#{attribute}_start` and `#{attribute}_end` sub-fields. |
| `legend:` | String | `human_attribute_name` | Fieldset legend text |

**How it works:** Wraps two `date_picker` calls (`#{attribute}_start` and `#{attribute}_end`) inside a fieldset. The start/end labels and hints are pulled from Strata i18n keys (`strata.form_builder.date_range.start_label`, etc.).

#### `memorable_date`

Renders a month select, day input, and year input for dates that users type from memory (e.g., date of birth).

```erb
f.memorable_date :date_of_birth, legend: t(".dob_legend")
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Attribute name. Must back a value that responds to `.month`, `.day`, `.year` or store a hash with those keys. |
| `legend:` | String | `human_attribute_name` | Fieldset legend text |
| `hint:` | String | i18n default | Hint text. Defaults to `strata.form_builder.memorable_date_hint` |

**How it works:** Uses `fields_for` to render three sub-fields (`month`, `day`, `year`) nested under the attribute name. Month is a `<select>` with full month names. Day and year are numeric text inputs with `inputmode="numeric"` and appropriate `pattern` and `maxlength` attributes.

See: [USWDS Memorable Date](https://designsystem.digital.gov/components/memorable-date/)

#### `name`

Renders first name, middle name (optional), last name, and suffix (optional) fields inside a fieldset.

```erb
f.name :member_name
f.name :member_name, legend: t(".full_name")
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Base attribute name. Generates `#{attribute}_first`, `#{attribute}_middle`, `#{attribute}_last`, `#{attribute}_suffix` sub-fields. |
| `legend:` | String | i18n default | Fieldset legend. Defaults to `strata.form_builder.name.legend` |
| `first_hint:` | String | i18n default | Hint for first name field |
| `last_hint:` | String | i18n default | Hint for last name field |

**How it works:** Renders four text fields in a fieldset. Middle name and suffix are marked `optional: true`. All fields use `autocomplete` attributes (`given-name`, `additional-name`, `family-name`, `honorific-suffix`) for browser autofill support.

#### `address_fields`

Renders a complete US mailing address form: street line 1, street line 2 (optional), city, state (select), and ZIP code.

```erb
f.address_fields :mailing_address
f.address_fields :home_address, legend: t(".home_address")
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Base attribute name. Generates `#{attribute}_street_line_1`, `#{attribute}_street_line_2`, `#{attribute}_city`, `#{attribute}_state`, `#{attribute}_zip_code` sub-fields. |
| `legend:` | String | i18n default | Fieldset legend. Defaults to `strata.form_builder.address.legend` |

**How it works:** Renders five fields in a fieldset. Street line 2 is marked `optional: true`. The state dropdown uses `us_states_and_territories` which includes all 50 states, DC, US territories, and Armed Forces designations. ZIP code uses `inputmode="numeric"` with a pattern for 5-digit or 5+4 format.

#### `money_field`

Renders a text input optimized for dollar amounts.

```erb
f.money_field :monthly_income, label: t(".income")
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | Attribute name. If the model value responds to `.dollar_amount`, that value is used for display. |
| `label:` | String | `human_attribute_name` | Label text |
| `hint:` | String | `nil` | Hint text |
| `inputmode:` | String | `"decimal"` | Browser keyboard hint. Defaults to decimal for dollar amounts. |
| `group_options:` | Hash | `{}` | HTML attributes for the wrapping form group |

**How it works:** Reads the current value and extracts `dollar_amount` if the value is a Money object. Renders a standard text input with `inputmode="decimal"` for mobile numeric keyboards with decimal point.

#### `tax_id_field`

Renders a masked input for Social Security Numbers or Tax Identification Numbers.

```erb
f.tax_id_field :ssn
```

**Parameters:** Accepts the same options as `text_field`. Automatically sets:
- `inputmode: "numeric"` for numeric keyboard on mobile
- `placeholder: "_________"` for the mask pattern
- `width: "md"` for appropriate field width
- `usa-masked` CSS class for USWDS masked input behavior
- Format hint from `strata.form_builder.tax_id_format` i18n key

### Structure and layout

#### `fieldset`

Groups related fields under a `<fieldset>` with a `<legend>`.

```erb
f.fieldset t(".personal_info") do
  <%= f.text_field :first_name, label: t(".first_name") %>
  <%= f.text_field :last_name, label: t(".last_name") %>
end
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `legend` | String | required | Legend text for the fieldset |
| `large_legend:` | Boolean | `false` | If true, adds `usa-legend--large` class for prominent section headings |
| `attribute:` | Symbol | `nil` | If provided, the fieldset will render error messages for this attribute |
| `hint:` | String | `nil` | Hint text rendered below the legend |
| `group_options:` | Hash | `{}` | HTML attributes for the wrapping form group |

**Generated HTML structure:**

```html
<div class="usa-form-group" id="model_attr_form_group">
  <fieldset class="usa-fieldset">
    <legend class="usa-legend margin-top-0">Legend text</legend>
    <div class="usa-hint">Hint text</div>
    <span class="usa-error-message">Error message</span>
    <!-- child fields -->
  </fieldset>
</div>
```

#### `hidden_field`

Standard Rails hidden field, unchanged by the builder.

```erb
f.hidden_field :activity_type, value: activity.class.name.underscore
f.hidden_field :category, value: activity.try(:category)
```

#### `honeypot_field`

Renders an invisible anti-spam field. If a bot fills it in, the server can reject the submission.

```erb
f.honeypot_field
```

The field is rendered with `opacity-0 position-absolute z-bottom height-0 width-0` classes, `tabindex: -1`, and `autocomplete: "false"` to prevent legitimate users and browsers from interacting with it.

#### `form_group`

Low-level helper that wraps content in a `usa-form-group` div. Automatically adds `usa-form-group--error` when the attribute has validation errors.

```erb
f.form_group(:name) do
  <%# custom content %>
end

f.form_group(:name, { show_error: true, class: "extra-class" }) do
  <%# content with forced error styling %>
end
```

#### `field_error`

Renders the error message for a specific attribute as a `<span class="usa-error-message">`.

```erb
f.field_error :name
```

Returns an empty safe string if the attribute has no errors.

### Conditional fields

Show or hide form sections based on the value of another field. This uses the Strata `ConditionalFieldComponent` with a `strata--conditional-field` Stimulus controller.

```erb
<%= f.conditional :my_radio_attr, eq: "yes" do %>
  <%= f.text_field :follow_up_question, label: t(".follow_up") %>
<% end %>
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `attribute` | Symbol | required | The attribute whose value controls visibility |
| `eq:` | String/Array | required | The value(s) that make the content visible. Pass a string for a single match or an array for multiple. |
| `clear:` | Boolean | `false` | If true, hidden inputs inside the conditional block are cleared when the block is hidden. This prevents stale data from being submitted. |

**How it works:**

1. The `conditional` method reads the current value of the attribute from the model
2. It renders a `Strata::ConditionalFieldComponent` that wraps the block content
3. The component uses a Stimulus controller (`strata--conditional-field`) that listens for `change` events on the source radio buttons/select
4. When the source value matches `eq:`, the content is shown; otherwise it is hidden
5. If `clear: true`, hidden inputs inside the block are reset when the block hides

**Multiple match values:**

```erb
<%= f.conditional :status, eq: ["active", "pending"], clear: true do %>
  <%# shown when status is "active" or "pending" %>
  <%= f.text_field :reason, label: t(".reason") %>
<% end %>
```

### Submit buttons

```erb
f.submit t(".save")                                 # Standard button
f.submit t(".continue"), big: true                  # Large button with vertical margin
f.submit t(".save"), class: "usa-button--outline"   # Outline variant
f.submit t(".delete"), class: "usa-button--secondary" # Secondary (red) variant
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | String | `nil` | Button text |
| `big:` | Boolean | `false` | If true, adds `usa-button--big margin-y-6` classes |
| `class:` | String | `""` | Additional CSS classes. Common variants: `usa-button--outline`, `usa-button--secondary`, `usa-button--unstyled` |
| `data:` | Hash | `nil` | Data attributes for Stimulus targets or actions |

The `usa-button` class is always applied automatically.

---

## Error handling

### Inline field errors

The form builder automatically handles inline error display. When a model attribute has validation errors:

1. The wrapping `usa-form-group` div gets `usa-form-group--error` class added
2. A `<span class="usa-error-message">` is rendered between the label and the input
3. The input itself gets `usa-input--error` class added

No extra code is needed -- just use the standard field methods with a model that has errors.

### Fieldset-level errors

When using `fieldset` with an `attribute:` option, errors for that attribute are rendered inside the fieldset automatically:

```erb
f.fieldset t(".dates"), { attribute: :reporting_period } do
  <%# date fields %>
end
```

For explicit error rendering outside a fieldset:

```erb
<%= f.field_error :name %>
```

### Flash-based error display

For errors set in the controller via `flash[:errors]`, use the `AlertComponent` in the flash partial. The standard flash partial at `app/views/application/_flash.html.erb` handles this:

```erb
<%# In your layout or page template %>
<%= render partial: 'application/flash' %>
```

The flash partial renders:
- `flash[:notice]` as a success alert
- `flash[:errors]` as an error alert with a list of error messages
- Single errors as plain text, multiple errors as a `<ul>` list

### Controller-to-view error pattern

In the controller, set errors on the model and re-render:

```ruby
def create
  @model = Model.new(model_params)
  if @model.save
    redirect_to @model, notice: t(".success")
  else
    flash.now[:errors] = @model.errors.full_messages
    render :new, status: :unprocessable_entity
  end
end
```

In the view, the form builder picks up `@model.errors` automatically for inline errors, and the flash partial displays the summary.

---

## Accessibility

The Strata FormBuilder implements USWDS accessibility patterns automatically. Understanding these patterns helps when building custom form layouts.

### Labels

Every field method generates a `<label>` with `class="usa-label"` linked to the input via `for`/`id` attributes. When no `label:` option is provided, the builder uses `object.class.human_attribute_name(attribute)` which pulls from your i18n locale files.

**Always provide explicit label text via `t()`.** Relying on `human_attribute_name` defaults works but is less predictable across locales.

### Hints

When `hint:` is provided, the builder:
1. Renders a `<div class="usa-hint" id="#{attribute}_hint">` element
2. Adds `aria-describedby="#{attribute}_hint"` to the input

This ensures screen readers announce the hint text when the input receives focus.

### Errors

Error messages are rendered as `<span class="usa-error-message">` between the label and input. Screen readers announce these as part of the label group.

### Fieldsets

Radio groups, checkbox groups, and multi-field composites (date, name, address) are wrapped in `<fieldset class="usa-fieldset">` with `<legend class="usa-legend">`. This groups the fields semantically so screen readers announce the legend when entering the group.

### Required vs. optional

Fields are **required by default** in USWDS convention. Optional fields should be marked with `optional: true`:

```erb
f.text_field :middle_name, label: t(".middle_name"), optional: true
```

This appends "(optional)" as hint text inside the label, following USWDS guidance to mark exceptions rather than required fields.

### Screen-reader-only text

For cases where a visual label is redundant but an accessible label is needed:

```erb
<legend class="usa-sr-only">
  <%= @current_question["question"] %>
</legend>
```

The `usa-sr-only` class hides the element visually but keeps it in the accessibility tree.

### Autocomplete attributes

Composite fields (`name`, `address_fields`) set appropriate `autocomplete` attributes:
- `given-name`, `additional-name`, `family-name`, `honorific-suffix` for name fields
- `address-line1`, `address-line2`, `address-level2`, `address-level1`, `postal-code` for address fields

This enables browser autofill, which is both a usability and accessibility benefit.

---

## Migration from us_form_with

If you need to migrate a form from the legacy builder:

### Step 1: Change the helper call

```diff
- <%= us_form_with(model: @model) do |f| %>
+ <%= strata_form_with(model: @model) do |f| %>
```

### Step 2: Check radio button tile behavior

The legacy builder always applies tile styling. Strata also defaults to `tile: true`, so most radio buttons work without changes. If you explicitly set `tile: false` in the legacy builder (which it does not support), you can now do so in Strata.

### Step 3: Check fieldset error handling

The legacy builder does not render errors inside fieldsets. If you had manual `field_error` calls inside fieldsets, Strata handles this automatically when you pass `attribute:`:

```diff
  f.fieldset t(".dates"), { attribute: :date_range } do
-   <%= f.field_error :date_range %>
    <%# fields %>
  end
```

### Step 4: Consider using composite fields

If the legacy form manually builds name, address, or date inputs, replace them with the Strata composite methods:

```diff
- <%= f.text_field :first_name, label: t(".first_name") %>
- <%= f.text_field :middle_name, label: t(".middle_name") %>
- <%= f.text_field :last_name, label: t(".last_name") %>
+ <%= f.name :member_name %>
```

### Step 5: Update i18n keys

The legacy builder uses `us_form_with.*` i18n keys. Strata uses `strata.form_builder.*`. If you override any of these keys, update the references:

| Legacy key | Strata key |
|---|---|
| `us_form_with.optional` | `strata.form_builder.optional` |
| `us_form_with.boolean_true` | `strata.form_builder.boolean_true` |
| `us_form_with.boolean_false` | `strata.form_builder.boolean_false` |
| `us_form_with.tax_id_format` | `strata.form_builder.tax_id_format` |
| `us_form_with.date_picker_format` | `strata.form_builder.date_picker_format` |

---

## USWDS documentation links

The Strata FormBuilder implements these USWDS components. Refer to the official documentation for visual examples and detailed accessibility guidance:

- [Form controls overview](https://designsystem.digital.gov/components/form-controls/)
- [Text input](https://designsystem.digital.gov/components/text-input/)
- [Textarea](https://designsystem.digital.gov/components/textarea/)
- [Select](https://designsystem.digital.gov/components/select/)
- [Radio buttons](https://designsystem.digital.gov/components/radio-buttons/)
- [Checkbox](https://designsystem.digital.gov/components/checkbox/)
- [Date picker](https://designsystem.digital.gov/components/date-picker/)
- [Memorable date](https://designsystem.digital.gov/components/memorable-date/)
- [File input](https://designsystem.digital.gov/components/file-input/)
- [Fieldset and legend](https://designsystem.digital.gov/components/form/)
- [Form validation](https://designsystem.digital.gov/components/validation/)
- [Button](https://designsystem.digital.gov/components/button/)
- [Alert](https://designsystem.digital.gov/components/alert/)

### Source files

- Strata FormBuilder: `strata-sdk-rails/app/helpers/strata/form_builder.rb`
- Legacy UswdsFormBuilder: `reporting-app/app/helpers/uswds_form_builder.rb`
- `strata_form_with` helper: defined by the Strata SDK engine
- `us_form_with` helper: `reporting-app/app/helpers/application_helper.rb`
