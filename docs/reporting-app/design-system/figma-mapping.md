# Design System: Figma-to-Code Mapping

This document describes the bidirectional workflow for translating between Figma designs and OSCER code. OSCER uses the USWDS Figma Kit v3 as its design source and outputs ERB templates with USWDS utility classes, Strata SDK components, and Rails i18n conventions.

> **Machine-readable version**: `.claude/rules/design-system-figma-mapping.md` contains the compact rule set consumed by AI tooling. This document is the expanded human-readable reference.

---

## Table of Contents

- [Overview: Bidirectional Workflow](#overview-bidirectional-workflow)
- [Figma-to-Code: Component Mapping](#figma-to-code-component-mapping)
- [Code-to-Figma: Component Mapping](#code-to-figma-component-mapping)
- [Layout Translation Guide](#layout-translation-guide)
- [Spacing Token Mapping](#spacing-token-mapping)
- [Page Type to Layout Routing](#page-type-to-layout-routing)
- [Common Pattern Translations](#common-pattern-translations)
- [Bounded Context File Locations](#bounded-context-file-locations)

---

## Overview: Bidirectional Workflow

The OSCER design system operates on a two-way mapping between Figma and code:

**Figma to Code** (design implementation):
1. Designers create screens in Figma using the USWDS Figma Kit v3 component library.
2. Developers identify each Figma component and look up its OSCER code equivalent in the mapping tables below.
3. All text content is replaced with `t()` i18n calls -- English strings are never hardcoded into ERB templates.
4. Layout structures (auto-layout, grids, spacing) are translated to USWDS utility classes.
5. The resulting code uses `strata_form_with` for forms, ViewComponents for complex UI, and USWDS HTML classes for everything else.

**Code to Figma** (design review / documentation):
1. When reviewing existing code, developers can trace each ERB helper or USWDS class back to a specific Figma component.
2. This helps designers audit whether the implementation matches the design and identifies any drift.
3. The reverse mapping tables below provide this lookup.

**Foundational rules**:
- Output ERB + USWDS classes ONLY. Never output React, Tailwind, or raw HTML without USWDS classes.
- Always use `t()` for user-visible text. See the [i18n guide](i18n.md) for conventions.
- Use Strata SDK components when available; fall back to raw USWDS HTML classes only when Strata does not provide a wrapper.

---

## Figma-to-Code: Component Mapping

This table maps every USWDS Figma Kit v3 component to its OSCER code equivalent. Use this when implementing a Figma design.

### Alerts and Feedback

| USWDS Figma Component | OSCER Code Equivalent | Notes |
|---|---|---|
| Alert | `render AlertComponent.new(type: :info, message: t(".msg"))` | OSCER custom ViewComponent. Types: `:info`, `:success`, `:warning`, `:error` |
| Alert / Success | `render AlertComponent.new(type: :success, message: t(".msg"))` | Auto-sets `role="status"` |
| Alert / Error | `render AlertComponent.new(type: :error, heading: t(".heading"))` | Auto-sets `role="alert"`. Supports `with_body` slot for error lists |
| Alert with body | `render AlertComponent.new(type: :error, heading: t(".heading")) do \|c\| c.with_body { ... } end` | Use for error lists, complex content |
| Tag | `<span class="usa-tag"><%= status %></span>` | For colored tags: add `bg-gold text-ink` or similar utility classes |

### Buttons

| USWDS Figma Component | OSCER Code Equivalent | Notes |
|---|---|---|
| Button | `link_to t(".label"), path, class: "usa-button"` | For navigation. Use `f.submit` for form submission |
| Button / Outline | `link_to t(".label"), path, class: "usa-button usa-button--outline"` | Secondary action styling |
| Button / Big | `f.submit t(".label"), big: true` | Used for primary form submit actions |
| Button / Unstyled | `link_to t(".label"), path, class: "usa-button usa-button--unstyled"` | Link-styled button |
| Button group | `<div class="usa-button-group" role="group" aria-label="...">` | Wrap multiple buttons |

### Form Inputs

| USWDS Figma Component | OSCER Code Equivalent | Notes |
|---|---|---|
| Text input | `f.text_field :attr, label: t(".label")` | Via `strata_form_with` FormBuilder. Supports `hint:`, `width:` |
| Text input (with $ prefix) | `f.money_field :attr, label: t(".label")` | Strata composite field for dollar amounts |
| Text area | `f.text_area :attr, label: t(".label")` | |
| Select | `f.select :attr, options, { prompt: t(".prompt") }` | |
| Radio button (tile) | `f.radio_button :attr, value, { label: t(".label"), tile: true }` | Default tile style |
| Radio button (no tile) | `f.radio_button :attr, value, { label: t(".label"), tile: false }` | Compact radio |
| Checkbox (tile) | `f.check_box :attr, { label: t(".label") }` | Tile style by default |
| Date picker | `f.date_picker :attr` | USWDS date picker widget |
| Date range | `f.date_range :attr` | Start + end date pickers in fieldset |
| Memorable date | `f.memorable_date :attr` | Month select + day/year inputs |
| File input | `f.file_field :attr, label: t(".label")` | Add `multiple: true` for multi-file |
| Fieldset with Yes/No radios | `f.yes_no :attr, { legend: t(".legend") }` | Strata composite field |

### Navigation and Structure

| USWDS Figma Component | OSCER Code Equivalent | Notes |
|---|---|---|
| Accordion | `render Strata::US::AccordionComponent.new(heading_tag: :h4)` | Requires `heading_tag:`. Supports `is_bordered:`, `is_multiselectable:` |
| Breadcrumb | `render partial: "application/breadcrumbs"` | Pass `crumbs:` array and `current:` string |
| Side navigation | Sidenav layout with `usa-sidenav` | Set `layout "sidenav"` in controller |
| Step indicator | `render partial: "strata/shared/step_indicator"` | Pass `steps:` and `current_step:` |
| Process list | `<ol class="usa-process-list">` | Raw USWDS HTML |
| Collection | `<ul class="usa-collection">` | Used for task lists |

### Data Display

| USWDS Figma Component | OSCER Code Equivalent | Notes |
|---|---|---|
| Table | `render Strata::US::TableComponent.new(striped: true)` | ViewComponent with header/row slots. Options: `borderless`, `compact`, `stacked`, `width_full`, `scrollable` |
| Table (simple) | `<table class="usa-table usa-table--striped width-full">` | Raw USWDS HTML when ViewComponent is overkill |
| Summary box | `<div class="usa-summary-box" role="region">` | Requires `aria-labelledby` pointing to heading ID |
| Icon | `uswds_icon("icon_name", label: t(".label"), size: 3)` | Decorative (no `label:`) gets `aria-hidden`. Meaningful (with `label:`) gets `aria-label` |

---

## Code-to-Figma: Component Mapping

Use this table when reviewing existing code and needing to identify the corresponding Figma component.

### Components

| OSCER Code | USWDS Figma Component | Notes |
|---|---|---|
| `AlertComponent.new(type: :success)` | Alert / Success | |
| `AlertComponent.new(type: :error)` | Alert / Error | |
| `AlertComponent.new(type: :warning)` | Alert / Warning | |
| `AlertComponent.new(type: :info)` | Alert / Info | |
| `Strata::US::AccordionComponent` | Accordion | |
| `Strata::US::TableComponent` | Table | |
| `f.text_field` | Text input | |
| `f.text_area` | Text area | |
| `f.select` | Select | |
| `f.radio_button ... tile: true` | Radio button / Tile | |
| `f.radio_button ... tile: false` | Radio button | |
| `f.check_box` | Checkbox / Tile | |
| `f.date_picker` | Date picker | |
| `f.date_range` | Date range picker | |
| `f.memorable_date` | Memorable date | |
| `f.money_field` | Text input (with $ prefix in Figma) | |
| `f.yes_no` | Fieldset with 2 radio buttons (Yes/No) | |
| `f.submit ... big: true` | Button / Big | |
| `usa-button--outline` | Button / Outline variant | |
| `usa-tag` | Tag | |
| `usa-breadcrumb` | Breadcrumb | |
| `usa-sidenav` | Side navigation | |
| `uswds_icon("name")` | Icon from USWDS icon set | |
| `usa-summary-box` | Summary box | |
| `usa-process-list` | Process list | |

### Layouts

| OSCER Code | Figma Representation |
|---|---|
| `grid-container` | Frame with max-width constraint (1024px) |
| `grid-row grid-gap` | Auto-layout horizontal with 16px gap |
| `grid-col-6` | Child frame set to 50% width |
| `grid-col-12 tablet:grid-col-6` | Full-width on mobile frame, half-width on tablet |
| `display-flex flex-column gap-4` | Auto-layout vertical, 32px gap |
| `usa-section padding-y-4` | Section frame with 32px vertical padding |

---

## Layout Translation Guide

### Figma Auto-Layout to USWDS Grid/Flex

Figma's auto-layout properties map directly to USWDS utility classes:

| Figma Auto-Layout Property | USWDS Classes |
|---|---|
| Frame with 12-column grid | `<div class="grid-container"><div class="grid-row grid-gap">` |
| Auto-layout horizontal | `<div class="display-flex flex-row gap-{n}">` |
| Auto-layout vertical | `<div class="display-flex flex-column gap-{n}">` |
| Auto-layout with wrap | `<div class="display-flex flex-row flex-wrap gap-{n}">` |
| Space between (horizontal) | `<div class="display-flex flex-justify">` |
| Center-aligned (cross axis) | Add `flex-align-center` |
| Responsive stack-to-row | `<div class="display-flex flex-column tablet:flex-row gap-2">` |

### Figma Grid to USWDS Grid

Figma column grids translate to the USWDS 12-column grid system:

```erb
<%# Figma: 12-column grid frame %>
<div class="grid-container">
  <div class="grid-row grid-gap">
    <%# Figma: child spanning 6 of 12 columns %>
    <div class="grid-col-12 tablet:grid-col-6">
      Left column content
    </div>
    <div class="grid-col-12 tablet:grid-col-6">
      Right column content
    </div>
  </div>
</div>
```

Column width mapping from Figma percentages:
- 100% width = `grid-col-12`
- 75% width = `grid-col-9`
- ~67% width = `grid-col-8`
- 50% width = `grid-col-6`
- ~33% width = `grid-col-4`
- 25% width = `grid-col-3`

---

## Spacing Token Mapping

Figma uses pixel values; OSCER uses USWDS spacing units where 1 unit = 8px. Use this table to translate Figma spacing to USWDS utility classes.

| Figma Spacing (px) | USWDS Units | USWDS Margin Class | USWDS Padding Class |
|---|---|---|---|
| 0px | 0 | `margin-0` | `padding-0` |
| 2px | 2px | `margin-2px` | `padding-2px` |
| 4px | 05 | `margin-05` | `padding-05` |
| 8px | 1 | `margin-1` | `padding-1` |
| 12px | 105 | `margin-105` | `padding-105` |
| 16px | 2 | `margin-2` | `padding-2` |
| 20px | 205 | `margin-205` | `padding-205` |
| 24px | 3 | `margin-3` | `padding-3` |
| 32px | 4 | `margin-4` | `padding-4` |
| 40px | 5 | `margin-5` | `padding-5` |
| 48px | 6 | `margin-6` | `padding-6` |
| 56px | 7 | `margin-7` | `padding-7` |
| 64px | 8 | `margin-8` | `padding-8` |
| 72px | 9 | `margin-9` | `padding-9` |
| 80px | 10 | `margin-10` | `padding-10` |

Directional variants follow the pattern `{property}-{direction}-{units}`:
- `margin-top-4` = 32px top margin
- `padding-x-2` = 16px left + right padding
- `margin-y-6` = 48px top + bottom margin

For flexbox gaps, use the custom OSCER `gap-{n}` utilities with the same unit scale:
- `gap-1` = 8px gap, `gap-2` = 16px gap, `gap-4` = 32px gap, etc.

---

## Page Type to Layout Routing

When a Figma design shows a particular page structure, use the corresponding Rails layout and route scope.

| Figma Page Shows | Rails Layout File | Route Scope | Example Controller |
|---|---|---|---|
| Member-facing page | `application.html.erb` | Root-level routes | `ActivitiesController` |
| Staff-facing page | `oscer_staff.html.erb` | `/staff` namespace | `Staff::CertificationBatchUploadsController` |
| Login / registration page | `users.html.erb` | Devise routes | `Users::SessionsController` |
| Dashboard overview | `dashboard.html.erb` | Dashboard controller | `DashboardController` |
| Page with sidebar nav | `sidenav.html.erb` | Controller with sidenav | Controller sets `layout "sidenav"` |

### Layout hierarchy

```
application_base.html.erb        <-- Root: HTML shell, header, flash, USWDS JS
+-- application.html.erb         <-- 12-col grid + breadcrumbs (most pages)
|   +-- sidenav.html.erb         <-- Sidebar nav (4/3 col) + main (8/9 col)
|   +-- users.html.erb           <-- Two-column centered (login/registration)
+-- dashboard.html.erb           <-- Minimal wrapper (dashboard views)
+-- oscer_staff.html.erb         <-- Staff views (extends Strata staff layout)
```

### Identifying the layout from Figma

- **Header with "Medicaid Work Reporting Portal" + user nav**: Member layout (`application`)
- **Header with staff-specific nav / admin tools**: Staff layout (`oscer_staff`)
- **Centered card with login/register form**: Auth layout (`users`)
- **Greeting with task cards**: Dashboard layout (`dashboard`)
- **Left sidebar with section links**: Sidenav layout (`sidenav`)

---

## Common Pattern Translations

### Form Page

A Figma screen showing a form with labeled inputs and a submit button:

```erb
<% content_for :title, t(".title") %>

<%= render partial: "application/breadcrumbs", locals: {
  crumbs: [
    { label: t("breadcrumbs.home"), path: root_path },
    { label: t(".breadcrumb_parent"), path: parent_path }
  ],
  current: t(".breadcrumb_current")
} %>

<h1><%= t(".heading") %></h1>

<%= strata_form_with(model: [@parent, @child]) do |f| %>
  <%= f.text_field :name, label: t(".name_label"), hint: t(".name_hint") %>
  <%= f.select :category, @categories, { prompt: t(".category_prompt") } %>

  <%= f.fieldset t(".details_legend") do %>
    <%= f.radio_button :type, "hourly", { label: t(".hourly_label"), hint: t(".hourly_hint"), tile: true } %>
    <%= f.radio_button :type, "income", { label: t(".income_label"), hint: t(".income_hint"), tile: true } %>
  <% end %>

  <%= f.submit t(".continue"), big: true %>
<% end %>
```

### Data Table Page

A Figma screen showing a heading, optional filters, and a data table:

```erb
<% content_for :title, t(".title") %>

<h1><%= t(".heading") %></h1>
<p><%= t(".description") %></p>

<%= render Strata::US::TableComponent.new(striped: true, width_full: true) do |table| %>
  <% table.with_caption { t(".table_caption") } %>
  <% table.with_header do |h| %>
    <% h.with_cell(scope: "col") { t(".col_name") } %>
    <% h.with_cell(scope: "col") { t(".col_date") } %>
    <% h.with_cell(scope: "col") { t(".col_status") } %>
  <% end %>
  <% @items.each do |item| %>
    <% table.with_row do |r| %>
      <% r.with_cell { link_to item.name, item_path(item) } %>
      <% r.with_cell { l(item.created_at, format: :local_en_us) } %>
      <% r.with_cell { content_tag(:span, item.status, class: "usa-tag") } %>
    <% end %>
  <% end %>
<% end %>
```

### Detail Page with Accordion Sections

A Figma screen showing a heading followed by collapsible sections:

```erb
<% content_for :title, t(".title") %>

<h1><%= t(".heading") %></h1>

<%= render Strata::US::AccordionComponent.new(heading_tag: :h2, is_bordered: true) do |accordion| %>
  <% accordion.with_heading { t(".section_personal") } %>
  <% accordion.with_body do %>
    <dl>
      <dt><%= t(".name_label") %></dt>
      <dd><%= @record.name %></dd>
      <dt><%= t(".date_label") %></dt>
      <dd><%= l(@record.date, format: :long) %></dd>
    </dl>
  <% end %>

  <% accordion.with_heading { t(".section_documents") } %>
  <% accordion.with_body do %>
    <p><%= t(".documents_description") %></p>
  <% end %>
<% end %>
```

### Multi-Step Flow

A Figma screen showing a step indicator at the top with task-specific form content:

```erb
<% content_for :title, t(".title") %>

<%= render partial: "strata/shared/step_indicator", locals: {
  steps: @steps,
  current_step: @current_step
} %>

<h1><%= t(".step_heading") %></h1>

<%= strata_form_with(model: @model) do |f| %>
  <%= f.text_field :attr, label: t(".attr_label") %>
  <%= f.submit t(".continue"), big: true %>
<% end %>
```

### Error State

A Figma screen showing an error alert with a list of validation errors:

```erb
<%= render AlertComponent.new(type: :error, heading: t("flash.error_heading", count: @errors.count)) do |c| %>
  <% c.with_body do %>
    <ul class="usa-list">
      <% @errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  <% end %>
<% end %>
```

### Success Confirmation

A Figma screen showing a success alert after form submission:

```erb
<%= render AlertComponent.new(type: :success, message: t(".saved_successfully")) %>
```

---

## Bounded Context File Locations

When implementing a Figma design, place files in the correct bounded context directory. OSCER organizes code by domain.

| Domain | Controller | View Path | Locale File |
|---|---|---|---|
| Certifications | `CertificationCasesController` | `app/views/certification_cases/` | `config/locales/views/certification_cases/en.yml` |
| Activities | `ActivitiesController` | `app/views/activities/` | `config/locales/views/activities/en.yml` |
| Activity Reports | `ActivityReportApplicationFormsController` | `app/views/activity_report_application_forms/` | `config/locales/views/activity_report_application_forms/en.yml` |
| Exemptions | `ExemptionsController` | `app/views/exemptions/` | `config/locales/views/exemption_application_forms/en.yml` |
| Exemption Screener | `ExemptionScreenerController` | `app/views/exemption_screener/` | `config/locales/views/exemption_screener/en.yml` |
| Document AI | `DocumentStagingController` | `app/views/document_staging/` | `config/locales/views/document_staging/en.yml` |
| Staff views | `Staff::*Controller` | `app/views/staff/` | `config/locales/views/staff/en.yml` |
| Auth (Devise) | `Users::*Controller` | `app/views/users/` | `config/locales/views/users/en.yml` |
| Dashboard | `DashboardController` | `app/views/dashboard/` | `config/locales/views/dashboard/en.yml` |
| Information Requests | `InformationRequestsController` | `app/views/information_requests/` | `config/locales/views/information_requests/en.yml` |
| Tasks | `TasksController` | `app/views/tasks/` | `config/locales/views/tasks/en.yml` |
| Shared partials | N/A | `app/views/application/` | `config/locales/views/application/en.yml` |

### File naming conventions

- **Views**: `app/views/{controller_name}/{action}.html.erb`
- **Partials**: `app/views/{controller_name}/_{partial_name}.html.erb`
- **Components**: `app/components/{component_name}.rb` + `app/components/{component_name}.html.erb`
- **Locales**: `config/locales/views/{controller_name}/en.yml` (and `es-US.yml` for Spanish)
- **Stimulus controllers**: `app/javascript/controllers/{feature_name}_controller.js`

All paths are relative to `reporting-app/`.
