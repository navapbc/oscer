# OSCER Design System: Components

Complete reference for UI components in the OSCER reporting application. Components follow a hierarchy: prefer Strata SDK components, use OSCER custom components when extending or adding domain-specific behavior, and never rebuild what Strata already provides.

---

## Table of contents

- [Component hierarchy](#component-hierarchy)
- [OSCER custom components](#oscer-custom-components)
  - [AlertComponent](#alertcomponent)
- [Strata SDK components](#strata-sdk-components)
  - [Strata::US::TableComponent](#strataus-tablecomponent)
  - [Strata::US::AccordionComponent](#stratausaccordioncomponent)
  - [Strata::Cases::IndexComponent](#stratacasesindexcomponent)
  - [Strata::Flows::TaskListComponent](#strataflowstasklistcomponent)
  - [Strata::ConditionalFieldComponent](#strataconditionalfieldcomponent)
- [Helpers](#helpers)
  - [USWDS icon helper](#uswds-icon-helper)
  - [DocAI attribution helpers](#docai-attribution-helpers)
- [Feature flags in views](#feature-flags-in-views)
- [Extending components](#extending-components)

---

## Component hierarchy

OSCER uses a layered approach to UI components:

| Layer | Source | When to use | Examples |
|---|---|---|---|
| **Strata SDK components** | `strata-sdk-rails` gem | Default choice for tables, accordions, task lists, case indexes, conditional fields | `Strata::US::TableComponent`, `Strata::US::AccordionComponent` |
| **OSCER custom components** | `reporting-app/app/components/` | When Strata does not provide the component, or when domain-specific behavior is needed | `AlertComponent` |
| **Raw USWDS HTML** | Inline ERB | Simple one-off elements that do not justify a component (tags, badges, simple lists) | `<span class="usa-tag">` |

**Rationale:** The Strata SDK provides well-tested, accessible ViewComponents for common USWDS patterns. Using them ensures consistent behavior, reduces maintenance burden, and guarantees USWDS accessibility compliance. OSCER custom components are reserved for application-specific UI that Strata does not cover -- such as the AlertComponent with its auto-resolved ARIA roles and type constants.

**Key rule:** Never rebuild a component that Strata already provides. Before creating a new component, check the Strata SDK source in `strata-sdk-rails/app/components/` for an existing implementation. If Strata's version is close but needs modification, consider subclassing it rather than building from scratch.

---

## OSCER custom components

### AlertComponent

**Source files:**
- `reporting-app/app/components/alert_component.rb`
- `reporting-app/app/components/alert_component.html.erb`

A ViewComponent that renders a [USWDS alert](https://designsystem.digital.gov/components/alert/). Supports simple message display, headings, and complex body content via a slot.

#### Parameters

| Parameter | Type | Default | Required | Description |
|---|---|---|---|---|
| `type:` | Symbol/String | -- | Yes | Alert type. Must be one of `:info`, `:success`, `:warning`, `:error`. Maps to `usa-alert--#{type}` CSS class. |
| `heading:` | String | `nil` | No | Alert heading text. Rendered as an `<h2>` (or whatever `heading_level` specifies) with `usa-alert__heading` class. |
| `message:` | String | `nil` | No | Simple alert body text. Rendered as `<p class="usa-alert__text">`. Ignored when the `body` slot is used. |
| `heading_level:` | Integer | `2` | No | HTML heading level (1-6) for the heading element. |
| `classes:` | String | `nil` | No | Additional CSS classes appended to the root `usa-alert` div. |
| `style:` | String | `nil` | No | Inline CSS styles for the root div. |
| `role:` | String | auto | No | ARIA role attribute. Defaults to auto-resolution: `:error` type gets `role="alert"`, all others get `role="status"`. Pass an explicit string to override. Pass `nil` to omit the role attribute entirely. |

#### Slots

| Slot | Description |
|---|---|
| `body` | Custom body content. When provided, replaces the `message:` parameter. Use for lists, buttons, accordions, or any complex content inside the alert. |

#### Type constants

Use the module constants for type-safe references in Ruby code:

```ruby
AlertComponent::TYPES::INFO      # => "info"
AlertComponent::TYPES::SUCCESS   # => "success"
AlertComponent::TYPES::WARNING   # => "warning"
AlertComponent::TYPES::ERROR     # => "error"
AlertComponent::TYPES::ALL       # => ["info", "success", "warning", "error"]
```

Role constants are also available:

```ruby
AlertComponent::ROLES::ALERT   # => "alert"
AlertComponent::ROLES::STATUS  # => "status"
```

#### ARIA role auto-resolution

The AlertComponent automatically assigns the correct ARIA role based on the alert type:

- **Error alerts** (`type: :error`) get `role="alert"` -- this causes screen readers to immediately announce the content (assertive live region). Appropriate for validation errors and critical failures.
- **All other types** (`:info`, `:success`, `:warning`) get `role="status"` -- this is a polite live region that screen readers announce at the next convenient pause.

You can override this behavior by passing an explicit `role:` parameter, or pass `nil` to omit the role attribute entirely.

#### Usage examples

**Simple message alert:**

```erb
<%= render AlertComponent.new(type: :success, message: t(".saved")) %>
```

Renders:
```html
<div class="usa-alert usa-alert--success" role="status">
  <div class="usa-alert__body">
    <p class="usa-alert__text">Your changes have been saved.</p>
  </div>
</div>
```

**Alert with heading and message:**

```erb
<%= render AlertComponent.new(
  type: :error,
  heading: t(".error_heading"),
  message: t(".error_text")
) %>
```

Renders:
```html
<div class="usa-alert usa-alert--error" role="alert">
  <div class="usa-alert__body">
    <h2 class="usa-alert__heading">Something went wrong</h2>
    <p class="usa-alert__text">Please try again later.</p>
  </div>
</div>
```

**Alert with body slot for complex content:**

```erb
<%= render AlertComponent.new(type: :error, heading: t(".error_heading")) do |c| %>
  <% c.with_body do %>
    <ul class="usa-list">
      <% @model.errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  <% end %>
<% end %>
```

When the `body` slot is used, the `message:` parameter is ignored. The body content is rendered directly inside `usa-alert__body`, after the heading.

**Info alert with custom heading level:**

```erb
<%= render AlertComponent.new(
  type: :info,
  heading: t(".notice"),
  message: t(".notice_text"),
  heading_level: 3
) %>
```

**Alert with custom CSS classes:**

```erb
<%= render AlertComponent.new(
  type: :warning,
  message: t(".warning_text"),
  classes: "margin-bottom-4"
) %>
```

#### Real-world example: flash partial

The application flash partial (`app/views/application/_flash.html.erb`) demonstrates the full range of AlertComponent usage:

```erb
<% if flash[:notice] || flash[:errors] || alert || notice %>
  <div class="grid-row margin-bottom-3">
    <div class="grid-col-12">
      <%# Success flash %>
      <% if flash[:notice] || notice %>
        <%= render AlertComponent.new(
          type: AlertComponent::TYPES::SUCCESS,
          message: flash[:notice] || notice
        ) %>
      <% end %>

      <%# Error flash with complex body %>
      <% if flash[:errors] || alert %>
        <%= render AlertComponent.new(type: AlertComponent::TYPES::ERROR) do |c| %>
          <% c.with_body do %>
            <% if flash[:errors] %>
              <h3 class="usa-alert__heading">
                <%= t "flash.error_heading", count: flash[:errors].count %>
              </h3>
            <% end %>
            <div class="usa-alert__text">
              <% if alert %>
                <%= alert %>
              <% elsif flash[:errors].count == 0 %>
                <p><%= t('flash.error_fallback') %></p>
                <button class="usa-button usa-button--outline" onclick="location.reload();">
                  <%= t('flash.reload_page') %>
                </button>
              <% elsif flash[:errors].count == 1 %>
                <%= flash[:errors].first %>
              <% else %>
                <ul class="usa-list">
                  <% flash[:errors].each do |error| %>
                    <li><%= error %></li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

Note how the error alert uses the body slot to handle different error count scenarios (zero errors with a reload button, single error as text, multiple errors as a list).

---

## Strata SDK components

These components are provided by the `strata-sdk-rails` gem. They follow the [ViewComponent](https://viewcomponent.org/) pattern and render USWDS-compliant HTML.

### Strata::US::TableComponent

Renders a USWDS data table with slot-based API for headers, rows, and cells.

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `borderless:` | Boolean | `false` | Removes table borders (`usa-table--borderless`) |
| `striped:` | Boolean | `false` | Alternating row background colors (`usa-table--striped`) |
| `compact:` | Boolean | `false` | Reduced cell padding (`usa-table--compact`) |
| `stacked:` | Boolean | `false` | Stacked layout on narrow screens (`usa-table--stacked`) |
| `width_full:` | Boolean | `false` | Full-width table (`width-full`) |
| `scrollable:` | Boolean | `false` | Wraps table in a scrollable container |
| `sticky_header:` | Boolean | `false` | Fixed header row during scroll |
| `sortable:` | Boolean | `false` | Enables column sorting behavior |

#### Slots

| Slot | Description |
|---|---|
| `caption` | Table caption (block). Rendered as `<caption>`. |
| `header` | Header row. Yields a row object with `with_cell(scope:)` for `<th>` elements. |
| `row` (repeatable) | Body row. Yields a row object with `with_cell` for `<td>` elements. |

#### Usage example

```erb
<%= render Strata::US::TableComponent.new(striped: true, width_full: true) do |table| %>
  <% table.with_caption { t(".caption") } %>
  <% table.with_header do |h| %>
    <% h.with_cell(scope: "col") { t(".col_name") } %>
    <% h.with_cell(scope: "col") { t(".col_date") } %>
    <% h.with_cell(scope: "col") { t(".col_status") } %>
  <% end %>
  <% @items.each do |item| %>
    <% table.with_row do |r| %>
      <% r.with_cell { item.name } %>
      <% r.with_cell { l(item.created_at, format: :local_en_us) } %>
      <% r.with_cell do %>
        <span class="usa-tag"><%= item.status %></span>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

#### Alternative: raw USWDS HTML table

For simple tables or when you need full control over the markup, use raw HTML with USWDS classes:

```erb
<table class="usa-table usa-table--striped width-full">
  <thead>
    <tr>
      <th scope="col"><%= t(".col_name") %></th>
      <th scope="col"><%= t(".col_date") %></th>
    </tr>
  </thead>
  <tbody>
    <% @items.each do |item| %>
      <tr>
        <td><%= item.name %></td>
        <td><%= l(item.created_at, format: :local_en_us) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

Use the component when you need striped/compact/scrollable/sortable behavior with minimal markup. Use raw HTML for simple display tables or when integrating with other UI patterns.

See: [USWDS Table](https://designsystem.digital.gov/components/table/)

### Strata::US::AccordionComponent

Renders a USWDS accordion with expandable/collapsible sections.

#### Parameters

| Parameter | Type | Default | Required | Description |
|---|---|---|---|---|
| `heading_tag:` | Symbol | -- | Yes | HTML heading element for section headings (`:h2`, `:h3`, `:h4`, etc.) |
| `is_bordered:` | Boolean | `false` | No | Adds border styling to the accordion |
| `is_multiselectable:` | Boolean | `false` | No | Allows multiple sections to be open simultaneously. If `false`, opening one section closes others. |

#### Slots

| Slot | Description |
|---|---|
| `heading` (repeatable) | Section heading text. Each heading must have a matching body. |
| `body` (repeatable) | Section body content. Rendered inside a collapsible panel. |

**Important:** Headings and bodies must be added in matching pairs. The first `with_heading` corresponds to the first `with_body`, and so on.

#### Usage example

From `certification_cases/show.html.erb` -- a multi-section accordion displaying case details:

```erb
<%= render Strata::US::AccordionComponent.new(
  heading_tag: :h4,
  is_multiselectable: true
) do |component| %>

  <% component.with_heading { t(".certification_details") } %>
  <% component.with_body do %>
    <p>
      <span class="text-bold"><%= t(".member_name") %></span>
      <span><%= @certification&.member_name&.full_name %></span>
    </p>
    <p>
      <span class="text-bold"><%= t(".member_email") %></span>
      <span><%= @certification&.member_email %></span>
    </p>
  <% end %>

  <% component.with_heading { t(".tasks") } %>
  <% component.with_body do %>
    <%= render partial: 'tasks_section', locals: { tasks: @tasks } %>
  <% end %>

  <% component.with_heading { t(".information_requests") } %>
  <% component.with_body do %>
    <%= render partial: "certification_cases/information_requests",
        locals: { information_requests: @information_requests } %>
  <% end %>

  <% component.with_heading { t(".activity_report") } %>
  <% component.with_body do %>
    <% if @activity_report %>
      <%= render partial: 'activity_report_application_forms/staff_activity_report',
          locals: { activity_report: @activity_report } %>
    <% else %>
      <p><%= t(".no_activity_report") %></p>
    <% end %>
  <% end %>
<% end %>
```

**Choosing `heading_tag:`** -- Follow the document heading hierarchy. If the accordion appears under an `<h3>`, use `:h4` for the accordion headings. This maintains accessible heading structure for screen reader navigation.

See: [USWDS Accordion](https://designsystem.digital.gov/components/accordion/)

### Strata::Cases::IndexComponent

Renders a case listing page with Open/Closed tabs and a case table.

#### Parameters

| Parameter | Type | Default | Required | Description |
|---|---|---|---|---|
| `cases:` | Collection | -- | Yes | ActiveRecord collection of case objects |
| `model_class:` | Class | -- | Yes | The case model class (e.g., `CertificationCase`) |
| `title:` | String | -- | Yes | Page title displayed above the tabs |
| `case_row_component_class:` | Class | -- | Yes | A ViewComponent class that renders individual case rows. Must implement the expected row interface. |

#### Usage example

From `certification_cases/index.html.erb`:

```erb
<%= render Strata::Cases::IndexComponent.new(
  model_class: CertificationCase,
  cases: @cases,
  title: t(".title"),
  case_row_component_class: CertificationCases::CaseRowComponent
) %>
```

#### Customizing row rendering

The component delegates row rendering to the class passed via `case_row_component_class:`. To customize how each case row appears, create a ViewComponent that subclasses `Strata::Cases::CaseRowComponent`:

```ruby
# app/components/certification_cases/case_row_component.rb
class CertificationCases::CaseRowComponent < Strata::Cases::CaseRowComponent
  # Override methods to customize column content
end
```

The component handles:
- Tab navigation between open and closed cases
- Empty state messaging
- Table structure and headers

### Strata::Flows::TaskListComponent

Renders a multi-step task list as a `usa-collection` with status indicators.

#### Parameters

| Parameter | Type | Default | Required | Description |
|---|---|---|---|---|
| `flow:` | Object | -- | Yes | An application form or flow object that responds to the task list interface (provides steps with completion status) |
| `show_step_label:` | Boolean | `false` | No | Whether to display step labels (e.g., "Step 1", "Step 2") |

#### Usage example

```erb
<%= render Strata::Flows::TaskListComponent.new(
  flow: @application_form,
  show_step_label: true
) %>
```

#### Task states

The component renders each step with one of three visual states:

| State | Display | Action link text |
|---|---|---|
| Not started | No indicator | "Start" |
| In progress | In-progress indicator | "Continue" |
| Completed | Checkmark indicator | "Edit" |

The component also renders a "Review and Submit" button at the bottom, which is **disabled** until all tasks are marked complete.

### Strata::ConditionalFieldComponent

A Stimulus-driven component that shows or hides form content based on the value of another field. This component is typically used via the `f.conditional` form builder method (see the [forms documentation](forms.md#conditional-fields)) rather than rendered directly.

#### How it works

1. Wraps content in a `<div>` controlled by the `strata--conditional-field` Stimulus controller
2. Listens for `change` events on the source input (identified by `name` attribute)
3. Shows the content when the source value matches one of the specified match values
4. Optionally clears hidden inputs when the content is hidden (`clear: true`)

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source:` | String | required | The `name` attribute of the controlling input (e.g., `model[attribute]`) |
| `match:` | Array | required | Array of string values that trigger visibility |
| `initially_visible:` | Boolean | `false` | Whether the content is visible on initial page load |
| `clear:` | Boolean | `false` | Whether to clear input values inside the block when hidden |

#### Direct rendering (rare)

In most cases, use `f.conditional` from the form builder. If you need to render the component outside a form builder context:

```erb
<%= render Strata::ConditionalFieldComponent.new(
  source: "model[status]",
  match: ["active"],
  initially_visible: @model.status == "active",
  clear: true
) do %>
  <p>This content appears when status is "active".</p>
<% end %>
```

---

## Helpers

### USWDS icon helper

**Source:** `reporting-app/app/helpers/application_helper.rb`

The `uswds_icon` helper renders SVG icons from the USWDS icon sprite sheet.

#### Method signature

```ruby
uswds_icon(icon_name, label: nil, size: 3, css_class: "", style: nil)
```

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `icon_name` | String | required | Icon name from the USWDS sprite sheet. Must match a symbol ID in `@uswds/uswds/dist/img/sprite.svg`. |
| `label:` | String | `nil` | Accessible label. If `nil`, the icon is **decorative** (`aria-hidden="true"`). If present, the icon is **meaningful** (`aria-label` + `<title>` element). |
| `size:` | Integer | `3` | Icon size. Maps to `usa-icon--size-#{n}`. Valid values: 1 through 5. |
| `css_class:` | String | `""` | Additional CSS classes for the `<svg>` element. |
| `style:` | String | `nil` | Inline CSS styles for the `<svg>` element. |

#### Decorative vs. meaningful icons

The `label:` parameter determines the icon's accessibility behavior:

**Decorative icons** (no label) -- used when the icon accompanies visible text and adds no information for screen reader users:

```erb
<%= uswds_icon("check_circle", size: 4, css_class: "text-green margin-right-1") %>
<span>Approved</span>
```

Renders with `aria-hidden="true"` so screen readers skip it entirely.

**Meaningful icons** (with label) -- used when the icon conveys information that is not available in surrounding text:

```erb
<%= uswds_icon("warning", label: t(".warning_label"), css_class: "text-error") %>
```

Renders with `aria-label` and a `<title>` element so screen readers announce the label.

#### Generated HTML

```html
<!-- Decorative -->
<svg class="usa-icon usa-icon--size-4 text-green" focusable="false" role="img" aria-hidden="true">
  <use xlink:href="/assets/@uswds/uswds/dist/img/sprite.svg#check_circle"></use>
</svg>

<!-- Meaningful -->
<svg class="usa-icon usa-icon--size-3 text-error" focusable="false" role="img" aria-label="Warning">
  <title>Warning</title>
  <use xlink:href="/assets/@uswds/uswds/dist/img/sprite.svg#warning"></use>
</svg>
```

#### Common icon names

These icon names are used throughout the OSCER application:

| Icon name | Usage in OSCER |
|---|---|
| `check_circle` | Success indicators, completed tasks |
| `warning` | Low confidence alerts, error indicators |
| `person` | Self-reported activity attribution |
| `insights` | AI-assisted activity attribution |
| `edit` | AI-assisted with member edits attribution |
| `arrow_back` | Back navigation |
| `arrow_forward` | Forward navigation |
| `upload_file` | File upload areas |
| `description` | Document references |
| `delete` | Delete actions |

For the complete list of available icons, see the [USWDS icon catalog](https://designsystem.digital.gov/components/icon/).

### DocAI attribution helpers

**Source:** `reporting-app/app/helpers/activities_helper.rb`

These helpers support the Document AI feature by providing visual attribution indicators for activity data. They show users where activity data came from: self-reported, AI-extracted, AI-extracted with member edits, or AI-rejected with member override.

#### Evidence source constants

The attribution system is built on the `ActivityAttributions` module (`app/models/activity_attributions.rb`):

```ruby
ActivityAttributions::SELF_REPORTED                  # "self_reported"
ActivityAttributions::AI_ASSISTED                    # "ai_assisted"
ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS  # "ai_assisted_with_member_edits"
ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE    # "ai_rejected_member_override"
ActivityAttributions::STATE_PROVIDED                 # "state_provided"
```

#### `evidence_source_icon(evidence_source)`

Returns a hash with icon configuration for a given evidence source.

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `evidence_source` | String/nil | One of the `ActivityAttributions` constants. Falls back to `SELF_REPORTED` if nil or unrecognized. |

**Returns:** A hash with three keys:

| Key | Type | Description |
|---|---|---|
| `:icon` | String | USWDS icon name |
| `:color` | String | USWDS utility CSS class for the icon color |
| `:label` | String | Localized label from `activities.evidence_sources` i18n scope |

**Icon/color mapping:**

| Evidence source | Icon | Color class | Visual meaning |
|---|---|---|---|
| `self_reported` | `person` | `text-primary` (blue) | Member entered data manually |
| `ai_assisted` | `insights` | `text-gold` (gold) | AI extracted data from uploaded document |
| `ai_assisted_with_member_edits` | `edit` | `text-green` (green) | AI extracted data, member corrected before submission |
| `ai_rejected_member_override` | `warning` | `text-error` (red) | DocAI rejected the document but member proceeded anyway |

**Usage:**

```erb
<% icon = evidence_source_icon(activity.evidence_source) %>
<%= uswds_icon(icon[:icon], label: icon[:label], css_class: icon[:color]) %>
```

#### `attribution_field_classes(evidence_source)`

Returns CSS classes for styling a field wrapper with an attribution-colored background and border.

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `evidence_source` | String/nil | One of the `ActivityAttributions` constants. Falls back to `SELF_REPORTED` if nil. |

**Returns:** A string of CSS classes.

**Class mapping:**

| Evidence source | CSS classes |
|---|---|
| `self_reported` | `border-1px border-primary bg-attribution-primary` |
| `ai_assisted` | `border-1px border-gold bg-attribution-gold` |
| `ai_assisted_with_member_edits` | `border-1px border-green bg-attribution-green` |
| `ai_rejected_member_override` | `border-1px border-error bg-attribution-error` |

**Usage:**

```erb
<div class="<%= attribution_field_classes(activity.evidence_source) %> padding-2 radius-md">
  <%# Activity field content with colored border/background %>
</div>
```

The `bg-attribution-*` classes are custom OSCER CSS classes that provide subtle background tints matching the border color.

#### `confidence_display(confidence)`

Converts a raw confidence float (0.0-1.0) to a display hash with percentage and low-confidence flag.

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `confidence` | Float/nil | Confidence score from DocAI (0.0 to 1.0) |

**Returns:** `nil` if confidence is nil, otherwise a hash:

| Key | Type | Description |
|---|---|---|
| `:percentage` | Integer | Confidence as a whole-number percentage (e.g., 85) |
| `:low` | Boolean | `true` if percentage is below the configured threshold |

The low-confidence threshold is configured in `Rails.application.config.doc_ai[:low_confidence_threshold]`.

#### `confidence_cell_content(activity, confidence_by_activity)`

Renders confidence information for a table cell, including a warning icon for low-confidence values.

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `activity` | Activity | The activity model. Must respond to `ai_sourced?`. |
| `confidence_by_activity` | Hash | Maps activity IDs to confidence floats. |

**Returns:** HTML-safe string. Returns "--" for non-AI activities or nil confidence. Otherwise renders the percentage, prefixed with a warning icon if confidence is low.

**Usage:**

```erb
<td><%= confidence_cell_content(activity, @confidence_by_activity) %></td>
```

**Example rendered output:**

- Non-AI activity: "--"
- High confidence: "92%"
- Low confidence: "[warning icon] 45%"

#### `task_confidence(case_id, confidence_by_case)`

Returns confidence information for a case-level task display.

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `case_id` | UUID | The certification case ID |
| `confidence_by_case` | Hash | Maps case IDs to aggregate confidence floats |

**Returns:** A hash with `:conf` (the confidence display hash or nil) and `:low` (boolean).

---

## Feature flags in views

OSCER uses feature flags to gate unreleased or experimental UI. In views, check flags with the `feature_enabled?` helper:

```erb
<% if feature_enabled?(:doc_ai) %>
  <%# DocAI-specific UI: confidence columns, attribution icons, upload flows %>
<% end %>
```

**Current feature flags:**

| Flag | Purpose |
|---|---|
| `:doc_ai` | Gates all Document AI features: document upload, confidence scoring, attribution display, AI-assisted activity pre-fill |

**Usage patterns:**

```erb
<%# Conditionally add a table column %>
<% if feature_enabled?(:doc_ai) %>
  <th scope="col"><%= t(".confidence") %></th>
<% end %>

<%# Conditionally choose a navigation path %>
<% continue_path = feature_enabled?(:doc_ai) && !session[:doc_ai_skip] ?
    doc_ai_upload_path : standard_path %>

<%# Conditionally render a component section %>
<% if feature_enabled?(:doc_ai) %>
  <td><%= confidence_cell_content(activity, @confidence_by_activity) %></td>
<% end %>
```

Feature flags are defined in environment configuration. See `docs/feature-flags.md` for the full list and configuration details.

---

## Extending components

### Subclassing Strata components

When a Strata component is close to what you need but requires customization, subclass it:

```ruby
# app/components/certification_cases/case_row_component.rb
class CertificationCases::CaseRowComponent < Strata::Cases::CaseRowComponent
  # Override specific methods to customize rendering
  def status_display
    # Custom status rendering
  end
end
```

Pass the subclass to the parent component:

```erb
<%= render Strata::Cases::IndexComponent.new(
  cases: @cases,
  model_class: CertificationCase,
  title: t(".title"),
  case_row_component_class: CertificationCases::CaseRowComponent
) %>
```

### Creating new OSCER components

New components should:

1. **Live in `app/components/`** with a matching `.rb` and `.html.erb` file
2. **Inherit from `ViewComponent::Base`**
3. **Define constants** for enumerated values (like `AlertComponent::TYPES`)
4. **Use slots** for complex content areas
5. **Auto-resolve accessibility attributes** when possible (like AlertComponent's role auto-resolution)
6. **Accept `classes:` parameter** for CSS extensibility
7. **Validate inputs** in `initialize` (raise `ArgumentError` for invalid types, levels, etc.)
8. **Use i18n** for all user-visible default text

**Example structure:**

```ruby
# app/components/my_component.rb
class MyComponent < ViewComponent::Base
  module VARIANTS
    PRIMARY   = "primary"
    SECONDARY = "secondary"
    ALL = [PRIMARY, SECONDARY].freeze
  end

  renders_one :body

  def initialize(variant:, title: nil, classes: nil)
    @variant = variant.to_s
    raise ArgumentError, "Invalid variant: #{variant}" unless VARIANTS::ALL.include?(@variant)
    @title = title
    @classes = classes
  end

  attr_reader :variant, :title, :classes
end
```

```erb
<%# app/components/my_component.html.erb %>
<div class="my-component my-component--<%= variant %> <%= classes %>">
  <% if title.present? %>
    <h3 class="my-component__title"><%= title %></h3>
  <% end %>
  <% if body %>
    <%= body %>
  <% end %>
</div>
```

### Previewing components with Lookbook

OSCER uses [Lookbook](https://lookbook.build/) for component previews. See `docs/reporting-app/lookbook.md` for setup and usage details.

---

## Related documentation

- [Forms documentation](forms.md) -- Form builder reference with field methods and examples
- [USWDS Components](https://designsystem.digital.gov/components/overview/) -- Official USWDS component documentation
- [ViewComponent](https://viewcomponent.org/) -- Ruby ViewComponent framework documentation
- [Lookbook](docs/reporting-app/lookbook.md) -- Component preview reference
- [Feature flags](docs/feature-flags.md) -- Feature flag configuration

### Source files

- AlertComponent: `reporting-app/app/components/alert_component.rb`, `reporting-app/app/components/alert_component.html.erb`
- Flash partial: `reporting-app/app/views/application/_flash.html.erb`
- Icon helper: `reporting-app/app/helpers/application_helper.rb`
- Attribution helpers: `reporting-app/app/helpers/activities_helper.rb`
- Attribution constants: `reporting-app/app/models/activity_attributions.rb`
