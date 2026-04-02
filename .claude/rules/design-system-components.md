# Design System: Components

## Component Hierarchy

- Use **Strata SDK components** by default
- Use **OSCER custom components** when extending Strata or for OSCER-specific UI
- NEVER rebuild what Strata already provides

## AlertComponent (OSCER)

`app/components/alert_component.rb`

```erb
<%# Simple message %>
<%= render AlertComponent.new(type: :success, message: t(".saved")) %>

<%# With heading %>
<%= render AlertComponent.new(type: :error, heading: t(".error_heading"), message: t(".error_text")) %>

<%# With body slot (lists, buttons, complex content) %>
<%= render AlertComponent.new(type: :error, heading: t(".error_heading")) do |c| %>
  <% c.with_body do %>
    <ul class="usa-list">
      <% errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  <% end %>
<% end %>
```

- **Types**: `:info`, `:success`, `:warning`, `:error` (maps to `usa-alert--{type}`)
- **Roles**: Auto-resolved — `:error` type gets `role="alert"`, others get `role="status"`
- **Heading level**: `heading_level: 2` (default), accepts 1-6
- **Custom classes**: `classes:` param for additional CSS
- Use `AlertComponent::TYPES::SUCCESS` constants when referencing in Ruby code

## Strata::US::TableComponent

```erb
<%= render Strata::US::TableComponent.new(striped: true, width_full: true) do |table| %>
  <% table.with_caption { t(".caption") } %>
  <% table.with_header do |h| %>
    <% h.with_cell(scope: "col") { t(".col_name") } %>
    <% h.with_cell(scope: "col") { t(".col_date") } %>
  <% end %>
  <% @items.each do |item| %>
    <% table.with_row do |r| %>
      <% r.with_cell { item.name } %>
      <% r.with_cell { l(item.created_at, format: :local_en_us) } %>
    <% end %>
  <% end %>
<% end %>
```

Options: `borderless`, `striped`, `compact`, `stacked`, `width_full`, `scrollable`, `sticky_header`, `sortable`

Alternative: Raw USWDS HTML table with classes:
```erb
<table class="usa-table usa-table--striped width-full">
  <thead><tr><th scope="col">...</th></tr></thead>
  <tbody><tr><td>...</td></tr></tbody>
</table>
```

## Strata::US::AccordionComponent

```erb
<%= render Strata::US::AccordionComponent.new(heading_tag: :h4, is_bordered: true) do |accordion| %>
  <% accordion.with_heading { t(".section_1") } %>
  <% accordion.with_body do %>
    <p><%= t(".section_1_content") %></p>
  <% end %>
  <% accordion.with_heading { t(".section_2") } %>
  <% accordion.with_body do %>
    <p><%= t(".section_2_content") %></p>
  <% end %>
<% end %>
```

- `heading_tag:` required (`:h2`, `:h3`, `:h4`, etc.)
- `is_multiselectable: true` allows multiple open sections
- Headings and bodies must match in count

## Strata::Cases::IndexComponent

```erb
<%= render Strata::Cases::IndexComponent.new(
  cases: @cases,
  model_class: CertificationCase,
  title: t(".title"),
  case_row_component_class: CertificationCases::CaseRowComponent
) %>
```

- Renders Open/Closed tabs with case table
- Customize row rendering by subclassing `Strata::Cases::CaseRowComponent`

## Strata::Flows::TaskListComponent

```erb
<%= render Strata::Flows::TaskListComponent.new(
  flow: @application_form,
  show_step_label: true
) %>
```

- Renders task list as `usa-collection` with status indicators
- Task states: not started ("Start"), in progress ("Continue"), completed (checkmark + "Edit")
- Includes "Review and Submit" button (disabled until all tasks complete)

## ConditionalFieldComponent (Strata)

Used via FormBuilder's `f.conditional` method (see forms rules). Wraps content in a div controlled by `strata--conditional-field` Stimulus controller.

## USWDS Icon Helper

`app/helpers/application_helper.rb`

```erb
<%# Decorative icon (hidden from screen readers) %>
<%= uswds_icon("check_circle", size: 4, css_class: "text-green margin-right-1") %>

<%# Meaningful icon (announced to screen readers) %>
<%= uswds_icon("warning", label: t(".warning_label"), css_class: "text-error") %>
```

- `icon_name`: USWDS icon name from sprite sheet (e.g., `check_circle`, `warning`, `person`, `insights`, `edit`, `arrow_back`)
- `size:` 1-5 (default 3) maps to `usa-icon--size-{n}`
- `label:` nil = decorative (`aria-hidden`), present = meaningful (`aria-label` + `<title>`)

## DocAI Attribution Helpers

`app/helpers/activities_helper.rb`

```erb
<%# Get icon config for evidence source %>
<% icon = evidence_source_icon(activity.evidence_source) %>
<%= uswds_icon(icon[:icon], label: icon[:label], css_class: icon[:color]) %>

<%# Apply attribution background to a field wrapper %>
<div class="<%= attribution_field_classes(activity.evidence_source) %> padding-2 radius-md">

<%# Display confidence percentage %>
<%= confidence_cell_content(activity, @confidence_by_activity) %>
```

Evidence sources: `self_reported` (blue/person), `ai_assisted` (gold/insights), `ai_assisted_with_member_edits` (green/edit), `ai_rejected_member_override` (red/warning)

## Feature Flags in Views

```erb
<% if feature_enabled?(:doc_ai) %>
  <%# DocAI-specific UI %>
<% end %>
```

Gate feature-specific UI behind `feature_enabled?` checks. Current flags: `:doc_ai`.
