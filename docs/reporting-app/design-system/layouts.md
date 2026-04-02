# OSCER Layout System

The OSCER reporting application uses a layered layout system built on top of the [USWDS (U.S. Web Design System)](https://designsystem.digital.gov/) grid and component libraries. Layouts are ERB templates that nest via `render template:`, composing yield points so that individual views only provide the content they need.

This document covers the layout hierarchy, every `content_for` yield point, the USWDS grid system, navigation components, and guidance on choosing the right layout for a given page.

---

## Layout Hierarchy

```
application_base.html.erb          <-- Root: full HTML document shell
|                                      Provides: <html>, <head>, <body>, header,
|                                      flash messages, USWDS JS, footer area
|
+-- application.html.erb           <-- Standard content layout (most member pages)
|   |                                  Wraps yield in grid-container + grid-row
|   |                                  Renders inside application_base via :main_content
|   |
|   +-- sidenav.html.erb           <-- Sidebar navigation layout
|   |                                  Adds a usa-sidenav in :before_content_col
|   |                                  Narrows main content to 8/9 columns
|   |
|   +-- users.html.erb             <-- Auth/login layout
|                                      Two-column centered, light background
|                                      Left column: form content
|                                      Right column: :sidebar
|
+-- dashboard.html.erb             <-- Minimal wrapper for dashboard
|                                      Renders application_base directly (no grid)
|
+-- oscer_staff.html.erb           <-- Staff views
                                       Extends Strata staff layout
                                       Adds importmap JS tags
```

Each child layout calls `render template: 'layouts/parent'` at the bottom of its file, which triggers the parent to render with the child's `content_for` blocks already populated. This is standard Rails template inheritance -- no custom framework required.

---

## Layout Files in Detail

### `application_base.html.erb` -- The Root Layout

**Location:** `app/views/layouts/application_base.html.erb`

This is the outermost HTML shell. Every page in the application ultimately renders through this layout (except staff pages, which use the Strata staff layout). It provides:

- The `<!DOCTYPE html>` declaration and `<html>` tag with the current locale
- The `<head>` block (meta tags, CSRF, CSP, favicon, stylesheet, importmap JS, USWDS init JS)
- The site-wide header partial
- Flash message rendering
- The main content area
- USWDS JS bundle at the bottom of `<body>`

```erb
<%# Top-level layout for all pages in the application %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title>
      <%= content_for?(:title) ? "#{ yield(:title) } | #{ t('header.title') }" : t("header.title") %>
    </title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= favicon_link_tag asset_path('@uswds/uswds/dist/img/us_flag_small.png') %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= yield :head %>

    <%= javascript_importmap_tags %>
    <%= javascript_include_tag '@uswds/uswds/dist/js/uswds-init.min.js' %>
  </head>

  <body>
    <div class="display-flex flex-column minh-viewport">
      <%= render partial: 'application/header' %>

      <main id="main-content" class="grid-col-fill display-flex flex-column">
        <div class="grid-col-fill <%= yield :main_col_class %>">
          <section class="usa-section padding-y-4">
            <div class="grid-container">
              <%= render partial: 'application/flash' %>
            </div>
          </section>

          <%= content_for?(:main_content) ? yield(:main_content) : yield %>
        </div>
      </main>
    </div>

    <%= javascript_include_tag '@uswds/uswds/dist/js/uswds.min.js' %>
    <%= yield :scripts %>
  </body>
</html>
```

**Key structural decisions:**

- The outer `<div>` uses `display-flex flex-column minh-viewport` to ensure the page fills at least the full viewport height, pushing any footer to the bottom even on short-content pages.
- The `<main>` element uses `grid-col-fill` so it expands to consume remaining vertical space.
- Flash messages are always inside a `grid-container` so they respect the max-width constraint regardless of which child layout is active.
- The `main_content` yield point allows child layouts (like `application.html.erb`) to inject a fully structured grid. If no child layout provides `:main_content`, the default `yield` renders directly -- this is how `dashboard.html.erb` works.

### `application.html.erb` -- Standard Content Layout

**Location:** `app/views/layouts/application.html.erb`

This is the default layout for most member-facing pages. It wraps the page content in a USWDS `grid-container` with a `grid-row` and provides slots for optional sidebar columns.

```erb
<%# Typical content-only layout for all pages in the application %>
<%= content_for :main_content do %>
  <div class="grid-container">
    <div class="grid-row grid-gap">
      <%= yield :before_content_col %>
      <div class="grid-col-12 <%= yield :content_col_class %>" id="content">
        <%= content_for?(:content) ? yield(:content) : yield %>
      </div>
      <%= yield :after_content_col %>
    </div>
  </div>
<% end %>

<%= render template: 'layouts/application_base' %>
```

By default, the content column spans all 12 grid columns (`grid-col-12`). Child layouts like `sidenav` and `users` override `:content_col_class` to narrow the main column and place content in `:before_content_col` or `:after_content_col`.

### `sidenav.html.erb` -- Sidebar Navigation Layout

**Location:** `app/views/layouts/sidenav.html.erb`

Adds a USWDS sidenav component to the left of the main content area. The sidebar takes 4 columns on tablet and 3 on desktop; the main content takes the remaining 8 or 9 columns.

```erb
<%= content_for :content_col_class, 'tablet:grid-col-8 desktop:grid-col-9' %>
<% nav_items = [
  {
    path: dev_sandbox_path,
    label: t('.sidebar.index')
  },
  { path: "https://rubyonrails.org", label: t('.sidebar.rails') },
  { path: "https://guides.rubyonrails.org", label: t('.sidebar.rails_guides') },
] %>

<%= content_for :before_content_col do %>
  <nav aria-label="Side navigation"
       class="tablet:grid-col-4 desktop:grid-col-3 margin-bottom-4 tablet:margin-bottom-0">
    <ul class="usa-sidenav">
      <% nav_items.each do |item| %>
        <li class="usa-sidenav__item">
          <%= link_to item[:label], item[:path],
              class: current_page?(item[:path]) ? 'usa-current' : '' %>
        </li>
      <% end %>
    </ul>
  </nav>
<% end %>

<%= render template: 'layouts/application' %>
```

**How it works:** The sidenav layout sets `:content_col_class` to shrink the main content column, then fills `:before_content_col` with the sidebar `<nav>`. It then delegates to `application.html.erb`, which delegates to `application_base.html.erb`. The chain is: `sidenav -> application -> application_base`.

The `current_page?` helper applies the `usa-current` CSS class to highlight the active nav item.

### `users.html.erb` -- Auth/Login Layout

**Location:** `app/views/layouts/users.html.erb`

Used for Devise login, registration, and password reset pages. It creates a two-column centered layout with a light gray background.

```erb
<%= content_for :main_col_class, 'bg-base-lightest' %>
<%= content_for :content_col_class, 'tablet:grid-col-6 flex-align-self-center' %>

<%= content_for :after_content_col do %>
  <div class="grid-col-12 tablet:grid-col-6 padding-x-205">
    <%= yield :sidebar %>
  </div>
<% end %>

<%= render template: 'layouts/application' %>
```

**What makes it different:**

- Sets `:main_col_class` to `bg-base-lightest`, giving the entire main area a light gray background that visually distinguishes auth pages from the rest of the application.
- Narrows the content column to 6 columns on tablet+ and centers it vertically with `flex-align-self-center`.
- Provides an `:after_content_col` area for a `:sidebar` yield point (used for supplementary info like "Why create an account?" or help links).

### `dashboard.html.erb` -- Minimal Dashboard Layout

**Location:** `app/views/layouts/dashboard.html.erb`

The simplest child layout. It renders `application_base` directly with no grid wrapper, giving the dashboard view full control over its own layout structure.

```erb
<%= render template: 'layouts/application_base' %>
```

The dashboard view's content goes directly into the default `yield` of `application_base`, which means it appears inside the `<main>` tag but is not wrapped in any `grid-container` or `grid-row`. The view itself is responsible for providing its own grid structure.

### `oscer_staff.html.erb` -- Staff Views Layout

**Location:** `app/views/layouts/oscer_staff.html.erb`

Staff-facing pages use the Strata framework's staff layout rather than the OSCER member layout. This layout simply adds the JavaScript importmap tags and delegates to the Strata staff template.

```erb
<% content_for :head do %>
  <%= javascript_importmap_tags %>
<% end %>
<%= render template: "layouts/strata/staff" %>
```

The Strata staff layout provides its own header, navigation, and chrome appropriate for internal staff users.

---

## Yield Points (content_for) Reference

Every yield point in the layout system is documented below, organized by which layout defines it.

### Defined in `application_base.html.erb`

| Yield Point | Purpose | Example Usage |
|---|---|---|
| `:title` | Sets the browser tab title. Appended to the site name with a pipe separator. If omitted, only the site name is shown. | `<% content_for :title, t(".title") %>` |
| `:head` | Injects additional tags into `<head>` (extra stylesheets, meta tags, preloads). | `<% content_for :head do %><meta name="robots" content="noindex"><% end %>` |
| `:main_col_class` | CSS class(es) applied to the div wrapping the main content area. Used to set background color. | `<%= content_for :main_col_class, 'bg-base-lightest' %>` |
| `:main_content` | Replaces the entire main content area below the flash messages. Child layouts use this to inject their grid structure. If not provided, the default `yield` is used. | Used by `application.html.erb` to inject `grid-container` |
| `:scripts` | Injects additional JavaScript at the bottom of `<body>`, after the USWDS JS bundle. | `<% content_for :scripts do %><script>...</script><% end %>` |

### Defined in `application.html.erb`

| Yield Point | Purpose | Example Usage |
|---|---|---|
| `:content_col_class` | CSS class(es) for the main content column div. Defaults to none (full 12-col width). Override to narrow the column. | `<%= content_for :content_col_class, 'tablet:grid-col-8' %>` |
| `:before_content_col` | Content rendered before the main content column inside the grid-row. Used for sidebars/nav on the left. | Used by `sidenav.html.erb` to place the side navigation |
| `:after_content_col` | Content rendered after the main content column inside the grid-row. Used for sidebars on the right. | Used by `users.html.erb` for the login sidebar |
| `:content` | The inner content of the main content column. If not provided, the default `yield` is used. | Rarely used directly; views typically use the default yield |

### Defined in `users.html.erb`

| Yield Point | Purpose | Example Usage |
|---|---|---|
| `:sidebar` | Content for the right-hand column on auth pages (login, registration, password reset). | `<% content_for :sidebar do %>Help text here<% end %>` |

### Yield Point Flow Diagram

When a view renders through `application.html.erb`, here is how the yield points compose:

```
View template
  |
  +-- content_for :title        --> application_base <title>
  +-- content_for :head         --> application_base <head>
  +-- content_for :scripts      --> application_base bottom of <body>
  +-- default yield / :content  --> application grid-col content area
  |
  application.html.erb
  |   +-- :before_content_col   --> left of content column (sidenav)
  |   +-- :content_col_class    --> CSS class on content column div
  |   +-- :after_content_col    --> right of content column
  |   |
  |   +-- Wraps everything in :main_content
  |
  application_base.html.erb
      +-- :main_col_class       --> CSS class on main area wrapper
      +-- :main_content         --> entire grid structure from application.html.erb
```

---

## USWDS Grid System

OSCER uses the USWDS 12-column grid system. All grid usage follows the standard USWDS patterns documented at [designsystem.digital.gov/utilities/layout-grid/](https://designsystem.digital.gov/utilities/layout-grid/).

### Basic Structure

Every grid layout requires three levels of nesting:

```erb
<div class="grid-container">       <%# Sets max-width and horizontal padding %>
  <div class="grid-row grid-gap">  <%# Creates the flexbox row with gutters %>
    <div class="grid-col-12">      <%# Column that spans all 12 units %>
      Content here
    </div>
  </div>
</div>
```

- **`grid-container`** -- Sets a max-width (typically 1040px) and centers the content with horizontal padding. This is already provided by `application.html.erb`, so views rendered through that layout do not need to add their own.
- **`grid-row`** -- Creates a flex container for columns. Add `grid-gap` for standard gutters between columns.
- **`grid-col-{n}`** -- A column spanning `n` of 12 units. Available values: `1` through `12`, plus `fill` (takes remaining space) and `auto` (sizes to content).

### Responsive Breakpoints

USWDS provides two responsive breakpoint prefixes:

| Prefix | Breakpoint | Usage |
|---|---|---|
| *(none)* | All screen sizes | `grid-col-12` |
| `tablet:` | 640px and above | `tablet:grid-col-6` |
| `desktop:` | 1024px and above | `desktop:grid-col-3` |

Responsive classes override the base class at the specified breakpoint and above. The mobile-first approach means you set the smallest size first, then override at larger sizes.

### Common Grid Patterns

#### Full-Width Single Column

The default when using `application.html.erb` with no overrides. Content spans all 12 columns.

```erb
<%# No special grid needed -- application.html.erb provides grid-container %>
<h1><%= t(".heading") %></h1>
<p>Full-width content here.</p>
```

#### Two Equal Columns (Responsive)

Stacks vertically on mobile, splits 50/50 on tablet and above.

```erb
<div class="grid-row grid-gap">
  <div class="grid-col-12 tablet:grid-col-6">
    Left column content
  </div>
  <div class="grid-col-12 tablet:grid-col-6">
    Right column content
  </div>
</div>
```

#### Sidebar + Main Content

The pattern used by `sidenav.html.erb`. Sidebar is narrower, main content takes the remaining space.

```erb
<div class="grid-row grid-gap">
  <nav class="tablet:grid-col-4 desktop:grid-col-3">
    Sidebar navigation
  </nav>
  <div class="tablet:grid-col-8 desktop:grid-col-9">
    Main content area
  </div>
</div>
```

On mobile, both columns stack vertically (both are implicitly `grid-col-12`). On tablet, the sidebar takes 4 columns and content takes 8. On desktop, the sidebar narrows to 3 columns and content expands to 9.

#### Three-Column Layout

```erb
<div class="grid-row grid-gap">
  <div class="grid-col-12 tablet:grid-col-4">Column 1</div>
  <div class="grid-col-12 tablet:grid-col-4">Column 2</div>
  <div class="grid-col-12 tablet:grid-col-4">Column 3</div>
</div>
```

#### Centered Narrow Content

Used for forms or focused reading content.

```erb
<div class="grid-row">
  <div class="grid-col-12 tablet:grid-col-8 desktop:grid-col-6 margin-x-auto">
    Centered content
  </div>
</div>
```

### Grid Utility Classes Reference

| Class | Purpose |
|---|---|
| `grid-container` | Max-width content wrapper |
| `grid-row` | Flex row for columns |
| `grid-gap` | Standard gutter between columns |
| `grid-col-{1-12}` | Fixed-width column |
| `grid-col-fill` | Column fills remaining space |
| `grid-col-auto` | Column sizes to its content |
| `tablet:grid-col-{n}` | Column width at 640px+ |
| `desktop:grid-col-{n}` | Column width at 1024px+ |

---

## Navigation Components

### Header

**Partial:** `app/views/application/_header.html.erb`

The site-wide header uses the USWDS basic header pattern (`usa-header usa-header--basic`). It is rendered by `application_base.html.erb` and appears on every page.

The header contains:
- The site logo/title linking to the root path
- A language toggle (visible on desktop; also in the mobile navbar)
- A mobile menu button
- Primary navigation links (Dashboard, Account, Logout) visible only when the user is signed in

```erb
<header class="usa-header usa-header--basic">
  <div class="usa-nav-container">
    <div class="usa-navbar flex-row gap-1">
      <div class="usa-logo desktop:width-tablet">
        <em class="usa-logo__text">
          <a href="<%= url_for root_path %>">
            <%= t 'header.title' %>
          </a>
        </em>
      </div>
      <%= render partial: "application/language-toggle",
          locals: { container_class: "display-block desktop:display-none" } %>
      <button type="button" class="usa-menu-btn"><%= t("header.menu") %></button>
    </div>

    <nav aria-label="Primary navigation" class="usa-nav">
      <div class="usa-nav__inner">
        <button type="button" class="usa-nav__close">
          <img src="<%= asset_path('@uswds/uswds/dist/img/usa-icons/close.svg') %>"
               alt="<%= t 'header.close' %>" />
        </button>
        <ul class="usa-nav__primary usa-accordion">
          <% if user_signed_in? %>
            <li class="usa-nav__primary-item">
              <%= link_to t('header.dashboard'), dashboard_path, class: "usa-nav-link" %>
            </li>
            <li class="usa-nav__primary-item">
              <%= link_to t('header.account'), users_account_path, class: "usa-nav-link" %>
            </li>
            <li class="usa-nav__primary-item">
              <%= button_to t('header.logout'), destroy_user_session_path,
                  method: :delete, class: "usa-nav-link" %>
            </li>
          <% end %>
        </ul>
      </div>
    </nav>
  </div>
</header>
```

Note that the logout action uses `button_to` (which generates a `<form>` with a DELETE request) rather than `link_to`, since sign-out is a state-changing operation.

### Breadcrumbs

**Partial:** `app/views/application/_breadcrumbs.html.erb`

Renders a USWDS breadcrumb navigation component. The partial expects two local variables:

- `crumbs` -- An array of hashes, each with `:name` and `:url` keys for intermediate breadcrumb links
- `current_name` -- A string for the current page (displayed without a link, with `aria-current="page"`)

A "Home" link is always prepended automatically.

```erb
<nav class="usa-breadcrumb" aria-label="Breadcrumbs">
  <ol class="usa-breadcrumb__list">
    <li class="usa-breadcrumb__list-item">
      <%= link_to t("breadcrumbs.home"), root_path, class: "usa-breadcrumb__link" %>
    </li>
    <% crumbs.each do |crumb| %>
      <li class="usa-breadcrumb__list-item">
        <%= link_to crumb[:name], crumb[:url], class: "usa-breadcrumb__link" %>
      </li>
    <% end %>
    <li class="usa-breadcrumb__list-item usa-current" aria-current="page">
      <span><%= current_name %></span>
    </li>
  </ol>
</nav>
```

**Usage in a view:**

```erb
<%= render partial: "application/breadcrumbs", locals: {
  crumbs: [
    { name: t("breadcrumbs.cases"), url: certification_cases_path }
  ],
  current_name: t(".breadcrumb_current")
} %>
```

When a breadcrumb immediately precedes an `<h1>`, the custom SCSS rule `.usa-breadcrumb + h1 { margin-top: units(3); }` adds consistent spacing.

### Sidenav

The USWDS side navigation component is used in the `sidenav.html.erb` layout. It provides a vertical list of links with a visual indicator for the current page.

```erb
<nav aria-label="Side navigation">
  <ul class="usa-sidenav">
    <li class="usa-sidenav__item">
      <%= link_to "Label", path,
          class: current_page?(path) ? "usa-current" : "" %>
    </li>
  </ul>
</nav>
```

Key points:
- Always include `aria-label="Side navigation"` on the `<nav>` element for accessibility.
- Use `current_page?(path)` to conditionally apply `usa-current`, which adds the left-border active indicator.
- On mobile, the sidenav stacks above the content (since the grid columns both become `grid-col-12`). Add `margin-bottom-4 tablet:margin-bottom-0` to avoid it crowding the content on mobile.

### Step Indicator

For multi-step workflows (like form wizards), OSCER uses the Strata step indicator component:

```erb
<%= render partial: "strata/shared/step_indicator", locals: {
  steps: @steps,
  current_step: @current_step
} %>
```

The `@steps` variable is typically an array of step labels, and `@current_step` is the index or identifier of the active step.

### Flash Messages

**Partial:** `app/views/application/_flash.html.erb`

Flash messages are rendered automatically by `application_base.html.erb` inside a `grid-container`. They use the `AlertComponent` ViewComponent:

- **Success:** Shown for `flash[:notice]` or `notice`. Renders as a green success alert.
- **Error:** Shown for `flash[:errors]` (an array) or `alert` (a string). Renders as a red error alert with:
  - A heading showing the error count
  - A single message if there is one error
  - A bulleted list if there are multiple errors
  - A "Reload page" button if the error array is empty (edge case fallback)

Views do not need to render flash messages manually -- they are always handled by the base layout.

---

## Flexbox Patterns

USWDS provides flexbox utility classes that work alongside the grid system. These are used for layout within grid columns or for components that need flex behavior.

### Horizontal Row with Centered Items

```erb
<div class="display-flex flex-row gap-2 flex-align-center">
  <span class="usa-tag">Status</span>
  <span>Label text</span>
</div>
```

### Vertical Stack with Spacing

```erb
<div class="display-flex flex-column gap-4">
  <div>First item</div>
  <div>Second item</div>
  <div>Third item</div>
</div>
```

### Responsive: Stack on Mobile, Row on Tablet

```erb
<div class="display-flex flex-column tablet:flex-row gap-2">
  <div>Left on tablet, top on mobile</div>
  <div>Right on tablet, bottom on mobile</div>
</div>
```

Note: The `tablet:flex-row` responsive prefix requires the `$flex-direction-settings: (responsive: true)` USWDS theme setting, which OSCER has enabled.

### Space-Between with Vertical Centering

```erb
<div class="display-flex flex-justify flex-align-center">
  <h2>Title on the left</h2>
  <%= link_to "Action", path, class: "usa-button" %>
</div>
```

### Flex Utility Reference

| Class | CSS Equivalent |
|---|---|
| `display-flex` | `display: flex` |
| `flex-row` | `flex-direction: row` |
| `flex-column` | `flex-direction: column` |
| `flex-fill` | `flex: 1 1 0` |
| `flex-auto` | `flex: 0 1 auto` |
| `flex-justify` | `justify-content: space-between` |
| `flex-justify-center` | `justify-content: center` |
| `flex-justify-end` | `justify-content: flex-end` |
| `flex-align-center` | `align-items: center` |
| `flex-align-start` | `align-items: flex-start` |
| `flex-align-end` | `align-items: flex-end` |
| `flex-align-self-center` | `align-self: center` |
| `gap-{0-10}` | `gap: units(n)` (custom OSCER utility) |

The `gap-{n}` classes are custom OSCER utilities (not built into USWDS). They map to USWDS spacing units and are defined in `application.scss`. Use them with `display-flex` for consistent spacing between flex children without adding margins.

---

## Common Page Structure Patterns

### Standard Content Page

The most common pattern for member-facing pages. Uses the default `application` layout.

```erb
<% content_for :title, t(".title") %>

<%= render partial: "application/breadcrumbs", locals: {
  crumbs: [
    { name: t("breadcrumbs.cases"), url: certification_cases_path }
  ],
  current_name: t(".breadcrumb")
} %>

<h1><%= t(".heading") %></h1>

<p><%= t(".description") %></p>

<%# Page-specific content... %>
```

### Form Page

```erb
<% content_for :title, t(".title") %>

<%= render partial: "application/breadcrumbs", locals: {
  crumbs: [
    { name: t("breadcrumbs.cases"), url: certification_cases_path },
    { name: @certification_case.case_number,
      url: certification_case_path(@certification_case) }
  ],
  current_name: t(".breadcrumb")
} %>

<h1><%= t(".heading") %></h1>

<%= form_with model: @form, url: submit_path do |f| %>
  <%# Form fields... %>
  <div class="margin-top-4">
    <%= f.submit t(".submit"), class: "usa-button" %>
  </div>
<% end %>
```

### Dashboard Page (Custom Grid)

Since the dashboard layout provides no grid wrapper, the view must define its own structure:

```erb
<% content_for :title, t(".title") %>

<section class="usa-section">
  <div class="grid-container">
    <h1><%= t(".heading") %></h1>

    <div class="grid-row grid-gap">
      <div class="grid-col-12 tablet:grid-col-6">
        <%# Card or widget %>
      </div>
      <div class="grid-col-12 tablet:grid-col-6">
        <%# Card or widget %>
      </div>
    </div>
  </div>
</section>
```

### Auth Page with Sidebar

When rendering through the `users` layout, the view's default yield goes into the left column. Use `:sidebar` for the right column.

```erb
<% content_for :title, t(".title") %>

<h1><%= t(".heading") %></h1>

<%= form_with model: resource, url: session_path(resource_name) do |f| %>
  <%# Login form fields... %>
<% end %>

<% content_for :sidebar do %>
  <h2><%= t(".sidebar_heading") %></h2>
  <p><%= t(".sidebar_text") %></p>
<% end %>
```

---

## Routing Conventions: Member vs. Staff Views

OSCER serves two distinct audiences, each with their own layout and route namespace:

### Member Routes

Member-facing routes are defined at the root level. These pages use the `application` layout (or its children: `sidenav`, `users`, `dashboard`).

```
/                           # Root/landing page
/certifications             # Certification list
/certification_cases/:id    # Case detail
/activities                 # Activity list
/exemptions                 # Exemption list
/document_staging           # DocAI document upload
/users/sign_in              # Login (users layout)
/users/sign_up              # Registration (users layout)
```

All member routes produce UUID-based URLs:
```
/certification_cases/550e8400-e29b-41d4-a716-446655440000
```

### Staff Routes

Staff routes are scoped under the `/staff` namespace and use the `oscer_staff` layout (which extends Strata's staff layout). Staff controllers set their layout explicitly:

```ruby
class Staff::SomeController < StaffBaseController
  layout "oscer_staff"
end
```

Staff pages have a different header, navigation, and visual chrome provided by the Strata framework.

### Resource Conventions

| Pattern | Convention | Example |
|---|---|---|
| Collection of resources | `resources :things` (plural) | `resources :certification_cases` |
| Single-instance resource | `resource :thing` (singular) | `resource :document_staging` |
| Nested resources | Nested `resources` block | `resources :certification_cases do resources :activities end` |

---

## Choosing the Right Layout

| Scenario | Layout | How to Set |
|---|---|---|
| Standard member page with content | `application` | Default -- no explicit `layout` needed |
| Page needing sidebar navigation | `sidenav` | `layout "sidenav"` in the controller |
| Login, registration, password reset | `users` | Configured via Devise (`config/initializers/devise.rb`) |
| Dashboard or pages needing custom grid | `dashboard` | `layout "dashboard"` in the controller |
| Staff-facing pages | `oscer_staff` | `layout "oscer_staff"` in the controller |
| Need to override layout per-action | Any | `layout "name"` with conditional, or `render layout: "name"` in the action |

**Decision guide:**

1. **Does the page need a sidebar nav?** Use `sidenav`.
2. **Is it a Devise auth page?** Use `users`.
3. **Is it a staff page?** Use `oscer_staff`.
4. **Does the page need full control over its grid?** Use `dashboard`.
5. **Otherwise:** Use the default `application` layout.

---

## References

- [USWDS Layout Grid](https://designsystem.digital.gov/utilities/layout-grid/)
- [USWDS Header](https://designsystem.digital.gov/components/header/)
- [USWDS Breadcrumb](https://designsystem.digital.gov/components/breadcrumb/)
- [USWDS Side Navigation](https://designsystem.digital.gov/components/side-navigation/)
- [USWDS Step Indicator](https://designsystem.digital.gov/components/step-indicator/)
- [Rails Layouts and Rendering Guide](https://guides.rubyonrails.org/layouts_and_rendering.html)
