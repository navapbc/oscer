# Design System: Figma Mapping

## Critical Rules

- When translating Figma designs to code: output ERB + USWDS classes ONLY
- NEVER output React, Tailwind, or raw HTML without USWDS classes
- Map USWDS Figma kit v3 components to their OSCER code equivalents below
- ALWAYS use `t()` for text content — never hardcode English strings

## Figma-to-Code: Component Mapping

| USWDS Figma Component | OSCER Code Equivalent |
|------------------------|----------------------|
| Alert | `render AlertComponent.new(type: :info, message: t(".msg"))` |
| Accordion | `render Strata::US::AccordionComponent.new(heading_tag: :h4)` |
| Button | `link_to t(".label"), path, class: "usa-button"` or `f.submit` |
| Button / Outline | `class: "usa-button usa-button--outline"` |
| Button / Big | `f.submit t(".label"), big: true` |
| Text input | `f.text_field :attr, label: t(".label")` |
| Text area | `f.text_area :attr, label: t(".label")` |
| Select | `f.select :attr, options, { prompt: t(".prompt") }` |
| Radio button | `f.radio_button :attr, value, { label: t(".label"), tile: true }` |
| Radio button (no tile) | `f.radio_button :attr, value, { label: t(".label"), tile: false }` |
| Checkbox | `f.check_box :attr, { label: t(".label") }` |
| Date picker | `f.date_picker :attr` |
| Date range | `f.date_range :attr` |
| Memorable date | `f.memorable_date :attr` |
| File input | `f.file_field :attr, label: t(".label")` |
| Table | `render Strata::US::TableComponent.new(striped: true)` or `<table class="usa-table">` |
| Tag | `<span class="usa-tag">...</span>` |
| Breadcrumb | `render partial: "application/breadcrumbs"` |
| Side navigation | sidenav layout with `usa-sidenav` |
| Step indicator | `render partial: "strata/shared/step_indicator"` |
| Summary box | `<div class="usa-summary-box" role="region">` |
| Process list | `<ol class="usa-process-list">` |
| Icon | `uswds_icon("icon_name", label: t(".label"), size: 3)` |
| Collection | `<ul class="usa-collection">` (task lists) |

## Figma-to-Code: Layout Mapping

| Figma Pattern | OSCER Code |
|---------------|------------|
| Frame with 12-col grid | `<div class="grid-container"><div class="grid-row grid-gap">` |
| Auto-layout horizontal | `<div class="display-flex flex-row gap-{n}">` |
| Auto-layout vertical | `<div class="display-flex flex-column gap-{n}">` |
| Auto-layout with wrap | `<div class="display-flex flex-row flex-wrap gap-{n}">` |
| Figma spacing 8px | `margin-1` or `padding-1` (1 USWDS unit = 8px) |
| Figma spacing 16px | `margin-2` or `padding-2` |
| Figma spacing 24px | `margin-3` or `padding-3` |
| Figma spacing 32px | `margin-4` or `padding-4` |
| Figma spacing 48px | `margin-6` or `padding-6` |

## Figma-to-Code: Page Type Routing

| Figma Page Shows | Use Layout | Route Scope |
|------------------|------------|-------------|
| Member-facing page | `application.html.erb` | Root-level routes |
| Staff-facing page | `oscer_staff.html.erb` | `/staff` namespace |
| Login / registration | `users.html.erb` | Devise routes |
| Dashboard overview | `dashboard.html.erb` | Dashboard controller |
| Page with sidebar nav | `sidenav.html.erb` | Controller with sidenav |

## Code-to-Figma: Component Mapping

| OSCER Code | USWDS Figma Component |
|------------|----------------------|
| `AlertComponent.new(type: :success)` | Alert / Success |
| `AlertComponent.new(type: :error)` | Alert / Error |
| `Strata::US::AccordionComponent` | Accordion |
| `Strata::US::TableComponent` | Table |
| `f.text_field` | Text input |
| `f.radio_button ... tile: true` | Radio button / Tile |
| `f.check_box` | Checkbox / Tile |
| `f.date_picker` | Date picker |
| `f.money_field` | Text input (with $ prefix in Figma) |
| `f.yes_no` | Fieldset with 2 radio buttons (Yes/No) |
| `f.submit ... big: true` | Button / Big |
| `usa-button--outline` | Button / Outline variant |
| `usa-tag` | Tag |
| `usa-breadcrumb` | Breadcrumb |
| `usa-sidenav` | Side navigation |
| `uswds_icon("name")` | Icon from USWDS icon set |
| `usa-summary-box` | Summary box |
| `usa-process-list` | Process list |

## Code-to-Figma: Layout Mapping

| OSCER Code | Figma Representation |
|------------|---------------------|
| `grid-container` | Frame with max-width constraint (1024px) |
| `grid-row grid-gap` | Auto-layout horizontal with 16px gap |
| `grid-col-6` | Child frame set to 50% width |
| `display-flex flex-column gap-4` | Auto-layout vertical, 32px gap |
| `tablet:grid-col-6` | Responsive variant: full-width on mobile frame, half on tablet |
| `usa-section padding-y-4` | Section frame with 32px vertical padding |

## Bounded Context → File Location

When generating code from Figma, place files in the correct bounded context:

| Domain | Controller Namespace | View Path |
|--------|---------------------|-----------|
| Certifications | `CertificationCasesController` | `views/certification_cases/` |
| Activities | `ActivitiesController` | `views/activities/` |
| Exemptions | `ExemptionsController` | `views/exemptions/` |
| Document AI | `DocumentStagingController` | `views/document_staging/` |
| Staff views | `Staff::*Controller` | `views/staff/` |
| Auth | `Users::*Controller` | `views/users/` |
| Dashboard | `DashboardController` | `views/dashboard/` |

## Common Figma Pattern Translations

**Form page**: `application` layout → `strata_form_with` → field methods → `f.submit big: true`

**Data table page**: `application` layout → heading → optional filters → `Strata::US::TableComponent` or `usa-table`

**Detail page with sections**: `application` layout → heading → `Strata::US::AccordionComponent` or card sections

**Multi-step flow**: `application` layout → step indicator partial → form with task-specific fields

**Error state**: `AlertComponent.new(type: :error)` with body slot listing errors
