# Design System: Layouts

## Layout Hierarchy

```
application_base.html.erb     ← Root: HTML shell, header, flash, USWDS JS
├── application.html.erb      ← 12-col grid + breadcrumbs (most pages)
│   ├── sidenav.html.erb      ← Sidebar nav (4/3 col) + main (8/9 col)
│   └── users.html.erb        ← Two-column centered (login/registration)
├── dashboard.html.erb        ← Minimal wrapper (dashboard views)
└── oscer_staff.html.erb      ← Staff views (extends Strata staff layout)
```

## Layout Selection Rules

| Page Type | Layout | Set via |
|-----------|--------|---------|
| Member pages (default) | `application` | Default layout |
| Staff pages | `oscer_staff` | `layout "oscer_staff"` in controller |
| Auth (login, register) | `users` | `layout "users"` in Devise config |
| Dashboard | `dashboard` | `layout "dashboard"` in controller |
| Sidebar navigation | `sidenav` | `layout "sidenav"` in controller |

## Yield Points (content_for)

| Yield | Purpose | Used in |
|-------|---------|---------|
| `:title` | Page title (appended to site name) | `application_base` |
| `:main_content` | Full main area override | `application_base` |
| `:content_col_class` | Column width CSS class | `application` |
| `:main_col_class` | Background color for main area | `application_base` |
| `:before_content_col` | Sidebar/nav before main content | `application` |
| `:after_content_col` | Sidebar content after main | `application` |
| `:content` | Inner content area | `application` |
| `:head` | Extra `<head>` tags | `application_base` |
| `:scripts` | Extra JS at bottom of body | `application_base` |
| `:sidebar` | Sidebar content in users layout | `users` |

## Page Structure Pattern

```erb
<% content_for :title, t(".title") %>

<%# Breadcrumbs (if applicable) %>
<%= render partial: "application/breadcrumbs", locals: { crumbs: [...], current: t(".breadcrumb") } %>

<h1><%= t(".heading") %></h1>

<%# Page content... %>
```

## USWDS Grid System

```erb
<%# Full-width container %>
<div class="grid-container">
  <div class="grid-row grid-gap">
    <div class="grid-col-12"><%= content %></div>
  </div>
</div>

<%# Two-column responsive %>
<div class="grid-row grid-gap">
  <div class="grid-col-12 tablet:grid-col-6">Left</div>
  <div class="grid-col-12 tablet:grid-col-6">Right</div>
</div>

<%# Sidebar + main %>
<div class="grid-row grid-gap">
  <nav class="tablet:grid-col-4 desktop:grid-col-3">Sidebar</nav>
  <div class="tablet:grid-col-8 desktop:grid-col-9">Main</div>
</div>
```

- Breakpoint prefixes: `tablet:` (640px+), `desktop:` (1024px+)
- Column classes: `grid-col-1` through `grid-col-12`, `grid-col-fill`, `grid-col-auto`
- Gap: `grid-gap` (default), or custom `.gap-{0-10}` for flexbox

## Navigation Components

### Header
`app/views/application/_header.html.erb` — USWDS basic header with primary nav, language toggle, mobile menu.

### Breadcrumbs
```erb
<%= render partial: "application/breadcrumbs", locals: {
  crumbs: [
    { label: t("breadcrumbs.home"), path: root_path },
    { label: t("breadcrumbs.cases"), path: cases_path }
  ],
  current: t(".breadcrumb_current")
} %>
```
Uses `usa-breadcrumb` with `aria-current="page"` on current item.

### Sidenav
```erb
<nav aria-label="Side navigation">
  <ul class="usa-sidenav">
    <li class="usa-sidenav__item">
      <%= link_to "Label", path, class: current_page?(path) ? "usa-current" : "" %>
    </li>
  </ul>
</nav>
```

### Step Indicator
```erb
<%= render partial: "strata/shared/step_indicator", locals: {
  steps: @steps, current_step: @current_step
} %>
```

## Flexbox Patterns

```erb
<%# Horizontal flex with gap %>
<div class="display-flex flex-row gap-2 flex-align-center">

<%# Vertical stack %>
<div class="display-flex flex-column gap-4">

<%# Responsive: stack on mobile, row on tablet %>
<div class="display-flex flex-column tablet:flex-row gap-2">

<%# Justify/align %>
<div class="display-flex flex-justify flex-align-center">
```

## Backend: Routing Conventions

- Member routes: root-level (`/certifications`, `/activities`)
- Staff routes: scoped under `/staff` namespace
- Singular resources for single-instance: `resource :document_staging`
- Nested resources: `resources :certification_cases do resources :activities end`
- UUID-based URLs: `/certification_cases/550e8400-e29b-41d4-a716-446655440000`
