# OSCER Styles and CSS Reference

OSCER's visual design is built on the [U.S. Web Design System (USWDS)](https://designsystem.digital.gov/). All styling uses USWDS utility classes, USWDS component classes, or custom SCSS written with USWDS token functions. Raw hex colors, arbitrary pixel values, and Tailwind classes are never used.

This document covers the USWDS theme configuration, the complete utility class reference, custom OSCER-specific styles, the color token system, typography, responsive design, and SCSS best practices.

---

## USWDS Theme Configuration

**File:** `app/assets/stylesheets/_uswds-theme.scss`

OSCER overrides a subset of USWDS settings to customize the design system for this application. These settings are passed to `uswds-core` via `@use ... with (...)`:

```scss
@use "uswds-core" with (
  // Disable scary but mostly irrelevant warnings:
  $theme-show-notifications: false,

  // Ensure utility classes always override other styles
  $utilities-use-important: true,

  // For turning columns into rows or vice versa on breakpoints
  $flex-direction-settings: (
    responsive: true
  ),

  // Use USWDS defaults for typography
  $theme-style-body-element: true,
  $theme-font-type-sans: "public-sans",
  $theme-global-content-styles: true,
  $theme-global-link-styles: true,
  $theme-global-paragraph-styles: true,

  $theme-h1-font-size: "2xl",
  $theme-h2-font-size: "lg",
  $theme-h3-font-size: "md",

  $theme-font-weight-semibold: 600,

  // See also: config/initializers/uswds.rb
  $theme-image-path: "@uswds/uswds/dist/img",
  $theme-font-path: "@uswds/uswds/dist/fonts"
);
```

### What Each Setting Does

| Setting | Value | Purpose |
|---|---|---|
| `$theme-show-notifications` | `false` | Suppresses USWDS console warnings during compilation that are not relevant to OSCER |
| `$utilities-use-important` | `true` | Adds `!important` to all utility classes so they reliably override component styles. This is critical because USWDS component CSS can be quite specific. |
| `$flex-direction-settings` | `(responsive: true)` | Enables responsive variants for flex-direction classes (e.g., `tablet:flex-row`). Without this, only the base `flex-row`/`flex-column` classes are available. |
| `$theme-style-body-element` | `true` | Applies base typography styles to the `<body>` element |
| `$theme-font-type-sans` | `"public-sans"` | Sets the primary sans-serif font to [Public Sans](https://public-sans.digital.gov/), the standard USWDS font for government websites |
| `$theme-global-content-styles` | `true` | Applies USWDS content styles globally (tables, lists, etc.) |
| `$theme-global-link-styles` | `true` | Applies USWDS link styles globally (color, underline, visited state) |
| `$theme-global-paragraph-styles` | `true` | Applies USWDS paragraph styles globally (max-width for readability) |
| `$theme-h1-font-size` | `"2xl"` | H1 heading size token |
| `$theme-h2-font-size` | `"lg"` | H2 heading size token |
| `$theme-h3-font-size` | `"md"` | H3 heading size token |
| `$theme-font-weight-semibold` | `600` | Weight for the `text-semibold` utility class |
| `$theme-image-path` | `"@uswds/uswds/dist/img"` | Path to USWDS image assets (icons, flags) |
| `$theme-font-path` | `"@uswds/uswds/dist/fonts"` | Path to USWDS font files |

### Stylesheet Load Order

**File:** `app/assets/stylesheets/application.scss`

```scss
@forward "uswds-theme";    // OSCER theme overrides (must come first)
@forward "uswds";          // Full USWDS library
@forward "sso";            // SSO-specific styles

@use "uswds-core" as *;    // Makes USWDS functions available (color(), units(), etc.)

// ... custom OSCER styles below ...
```

The `@forward` order matters: theme settings must be declared before USWDS is loaded so that USWDS compiles with the correct values. The `@use "uswds-core" as *` import makes all USWDS SCSS functions (`color()`, `units()`, `font-size()`) available for the custom styles that follow.

---

## Typography System

### Font Family

OSCER uses **Public Sans** as its sole font family, set via `$theme-font-type-sans: "public-sans"`. Public Sans is an open-source typeface designed for government digital services, optimized for readability on screens.

### Heading Sizes

| Element | USWDS Token | Approximate Size |
|---|---|---|
| `<h1>` | `2xl` | ~1.99rem (31.84px) |
| `<h2>` | `lg` | ~1.22rem (19.52px) |
| `<h3>` | `md` | ~1.06rem (16.96px) |

### Font Size Utility Classes

Use these to set text size independently of the semantic heading level:

```
font-sans-2xs     ~0.72rem
font-sans-xs      ~0.83rem
font-sans-sm      ~0.89rem
font-sans-md      ~1.06rem
font-sans-lg      ~1.22rem
font-sans-xl      ~1.41rem
font-sans-2xl     ~1.99rem
font-sans-3xl     ~2.44rem
```

### Font Weight

```
text-normal       font-weight: 400
text-semibold     font-weight: 600
text-bold         font-weight: 700
text-italic       font-style: italic
```

### Text Alignment

```
text-left         text-align: left
text-center       text-align: center
text-right        text-align: right
```

### Text Wrapping

```
text-no-wrap      white-space: nowrap
text-pre-wrap     white-space: pre-wrap
```

### Custom Text Wrapping Rules

OSCER applies intelligent text wrapping globally in `application.scss`:

```scss
h1, h2, h3, h4, label, legend {
  text-wrap: balance;
}

p, li, .usa-hint {
  text-wrap: pretty;
}
```

- **`text-wrap: balance`** on headings and labels distributes text more evenly across lines, avoiding orphans (a single word on the last line). This makes headings look visually balanced.
- **`text-wrap: pretty`** on body text optimizes line breaks to avoid orphans at the end of paragraphs without aggressively rebalancing every line.

The exemption screener has an override that resets wrapping to `auto` for its headings and paragraphs, since its content has specific formatting requirements.

### Breadcrumb-to-Heading Spacing

```scss
.usa-breadcrumb + h1 {
  margin-top: units(3);
}
```

When a breadcrumb navigation directly precedes an `<h1>`, this rule adds `1.5rem` of space between them. Without it, the heading sits too close to the breadcrumb.

---

## Utility Class Reference

All USWDS utility classes are available. Below is a categorized reference of the most commonly used utilities in OSCER.

### Spacing

USWDS spacing utilities use a unit scale where `1` = `0.5rem` (8px at default font size).

#### Margin

```
margin-{0-10}                      All sides
margin-top-{0-10}                  Top only
margin-bottom-{0-10}               Bottom only
margin-left-{0-10}                 Left only
margin-right-{0-10}                Right only
margin-x-{0-10}                    Left and right
margin-y-{0-10}                    Top and bottom
margin-x-auto                      Center horizontally
```

Half-unit values use a concatenated format: `margin-top-05` = 0.5 units, `margin-top-105` = 1.5 units, `margin-top-205` = 2.5 units.

#### Padding

```
padding-{0-10}                     All sides
padding-top-{0-10}                 Top only
padding-bottom-{0-10}              Bottom only
padding-left-{0-10}                Left only
padding-right-{0-10}               Right only
padding-x-{0-10}                   Left and right
padding-y-{0-10}                   Top and bottom
```

Same half-unit values apply: `padding-x-205` = 2.5 units of horizontal padding.

#### Spacing Unit Scale

| Value | rem | px (at 16px base) |
|---|---|---|
| `0` | 0 | 0 |
| `05` | 0.25rem | 4px |
| `1` | 0.5rem | 8px |
| `105` | 0.75rem | 12px |
| `2` | 1rem | 16px |
| `205` | 1.25rem | 20px |
| `3` | 1.5rem | 24px |
| `4` | 2rem | 32px |
| `5` | 2.5rem | 40px |
| `6` | 3rem | 48px |
| `7` | 3.5rem | 56px |
| `8` | 4rem | 64px |
| `9` | 4.5rem | 72px |
| `10` | 5rem | 80px |

**USWDS reference:** [designsystem.digital.gov/design-tokens/spacing-units/](https://designsystem.digital.gov/design-tokens/spacing-units/)

### Display and Visibility

```
display-flex                       Flex container
display-block                      Block element
display-inline-block               Inline block
display-none                       Hidden
```

Responsive variants are available:

```erb
<%# Hide on mobile, show on desktop %>
<div class="display-none desktop:display-block">
  Only visible on desktop
</div>

<%# Show on mobile, hide on desktop %>
<div class="display-block desktop:display-none">
  Only visible on mobile/tablet
</div>
```

#### Screen-Reader Only

```
usa-sr-only                        Visually hidden but accessible to screen readers
```

#### Honeypot Pattern (Visually Hidden from All Users)

```erb
<div class="opacity-0 position-absolute z-bottom height-0 width-0">
  <%# Bot trap field -- invisible to real users, read by bots %>
</div>
```

### Flexbox

See the [Layouts documentation](./layouts.md#flexbox-patterns) for complete flex patterns.

```
display-flex                       Enable flexbox
flex-row                           Direction: row (default)
flex-column                        Direction: column
flex-fill                          Grow to fill (flex: 1 1 0)
flex-auto                          Size to content (flex: 0 1 auto)
flex-justify                       justify-content: space-between
flex-justify-center                justify-content: center
flex-justify-end                   justify-content: flex-end
flex-align-center                  align-items: center
flex-align-start                   align-items: flex-start
flex-align-end                     align-items: flex-end
flex-align-self-center             align-self: center
```

Responsive variants (requires `$flex-direction-settings: (responsive: true)`):

```
tablet:flex-row                    Row direction at 640px+
tablet:flex-column                 Column direction at 640px+
desktop:flex-row                   Row direction at 1024px+
desktop:flex-column                Column direction at 1024px+
```

### Colors -- Text

Color utilities set the `color` property using USWDS design tokens.

```
text-primary                       Primary blue
text-base                          Base gray (dark)
text-base-dark                     Darker gray
text-base-light                    Lighter gray
text-error                         Red (error state)
text-warning                       Yellow/orange (warning state)
text-success                       Green (success state)
text-info                          Blue (informational)
text-gold                          Gold/yellow
text-green                         Green
text-white                         White
text-ink                           Default ink color (near-black)
```

**USWDS reference:** [designsystem.digital.gov/utilities/color/](https://designsystem.digital.gov/utilities/color/)

### Colors -- Background

```
bg-white                           White background
bg-base-lightest                   Very light gray (#f0f0f0)
bg-base-lighter                    Light gray
bg-base-light                      Medium-light gray
bg-primary                         Primary blue background
bg-primary-lighter                 Light blue background
bg-error-lighter                   Light red background
```

### Borders

#### Border Width

```
border-{1px/2px/05/1/105/2/205/3}         All sides
border-top-{1px/2px/05/1}                  Top only
border-bottom-{1px/2px/05/1}               Bottom only
border-left-{1px/2px/05/1}                 Left only
border-right-{1px/2px/05/1}                Right only
```

#### Border Color

```
border-primary                     Primary blue
border-gold                        Gold
border-green                       Green
border-error                       Red
border-base-lighter                Light gray
```

#### Border Radius

```
radius-md                          Medium radius (0.25rem)
radius-lg                          Large radius (0.5rem)
```

### Width and Size

```
width-full                         width: 100%
maxw-tablet                        max-width: 640px
minh-viewport                      min-height: 100vh
height-0                           height: 0
width-0                            width: 0
```

---

## USWDS Component Classes

These are the USWDS component classes most frequently used in OSCER templates.

### Buttons

```erb
<%# Primary button (solid blue) %>
<%= link_to t(".label"), path, class: "usa-button" %>

<%# Outline button (white with blue border) %>
<%= link_to t(".label"), path, class: "usa-button usa-button--outline" %>

<%# Big button (larger padding and font) %>
<%= link_to t(".label"), path, class: "usa-button usa-button--big" %>

<%# Unstyled button (looks like a link) %>
<%= link_to t(".label"), path, class: "usa-button usa-button--unstyled" %>

<%# Button group %>
<div class="usa-button-group" role="group" aria-label="Actions">
  <%= link_to t(".save"), save_path, class: "usa-button" %>
  <%= link_to t(".cancel"), cancel_path, class: "usa-button usa-button--outline" %>
</div>
```

**USWDS reference:** [designsystem.digital.gov/components/button/](https://designsystem.digital.gov/components/button/)

### Tags

```erb
<%# Default tag (dark background) %>
<span class="usa-tag"><%= status %></span>

<%# Custom-colored tag %>
<span class="usa-tag bg-gold text-ink"><%= custom_tag %></span>
```

**USWDS reference:** [designsystem.digital.gov/components/tag/](https://designsystem.digital.gov/components/tag/)

### Lists

```erb
<%# Standard bulleted list %>
<ul class="usa-list">
  <li>Item one</li>
  <li>Item two</li>
</ul>

<%# Unstyled list (no bullets, no padding) %>
<ul class="usa-list usa-list--unstyled">
  <li>Item one</li>
  <li>Item two</li>
</ul>

<%# Process list (numbered steps with descriptions) %>
<ol class="usa-process-list">
  <li class="usa-process-list__item">
    <h4 class="usa-process-list__heading">Step one</h4>
    <p>Description of step one.</p>
  </li>
</ol>
```

**USWDS reference:** [designsystem.digital.gov/components/list/](https://designsystem.digital.gov/components/list/)

### Summary Box

```erb
<div class="usa-summary-box" role="region" aria-labelledby="summary-heading">
  <div class="usa-summary-box__body">
    <h2 class="usa-summary-box__heading" id="summary-heading">
      Key information
    </h2>
    <div class="usa-summary-box__text">
      <p>Important summary content here.</p>
    </div>
  </div>
</div>
```

**USWDS reference:** [designsystem.digital.gov/components/summary-box/](https://designsystem.digital.gov/components/summary-box/)

### Sections

```erb
<%# Standard section (generous vertical padding) %>
<section class="usa-section">
  <div class="grid-container">Content</div>
</section>

<%# Light background section %>
<section class="usa-section usa-section--light">
  <div class="grid-container">Content</div>
</section>

<%# Reduced-padding section %>
<section class="usa-section padding-y-4">
  <div class="grid-container">Content</div>
</section>
```

**USWDS reference:** [designsystem.digital.gov/components/section/](https://designsystem.digital.gov/components/section/)

### Alerts

OSCER uses an `AlertComponent` ViewComponent rather than raw USWDS alert markup. See the flash messages section in the [layouts documentation](./layouts.md) for how alerts are rendered.

```erb
<%= render AlertComponent.new(
  type: AlertComponent::TYPES::SUCCESS,
  message: "Your changes have been saved."
) %>

<%= render AlertComponent.new(
  type: AlertComponent::TYPES::ERROR
) do |c| %>
  <% c.with_body do %>
    <div class="usa-alert__text">
      Detailed error description here.
    </div>
  <% end %>
<% end %>
```

**USWDS reference:** [designsystem.digital.gov/components/alert/](https://designsystem.digital.gov/components/alert/)

---

## Custom OSCER SCSS Utilities

OSCER defines a small number of custom utilities in `app/assets/stylesheets/application.scss` to fill gaps in USWDS or support application-specific features.

### Gap Utilities (`gap-0` through `gap-10`)

**Why this exists:** USWDS provides `grid-gap` for its grid system, but `grid-gap` does not work with generic flexbox layouts. The CSS `gap` property is the standard way to add space between flex children, but USWDS does not provide utility classes for it.

```scss
@for $i from 0 through 10 {
  .gap-#{$i} {
    gap: units($i);
  }
}
```

This generates 11 classes that map to the same USWDS spacing unit scale used by margin and padding utilities:

| Class | CSS Output | Equivalent Spacing |
|---|---|---|
| `gap-0` | `gap: 0` | 0 |
| `gap-1` | `gap: units(1)` | 0.5rem / 8px |
| `gap-2` | `gap: units(2)` | 1rem / 16px |
| `gap-3` | `gap: units(3)` | 1.5rem / 24px |
| `gap-4` | `gap: units(4)` | 2rem / 32px |
| `gap-5` | `gap: units(5)` | 2.5rem / 40px |
| ... | ... | ... |
| `gap-10` | `gap: units(10)` | 5rem / 80px |

**Usage:**

```erb
<div class="display-flex flex-row gap-2 flex-align-center">
  <span class="usa-tag">Pending</span>
  <span>Case #12345</span>
</div>
```

### Translation Missing Indicator

**Why this exists:** Rails wraps missing i18n translations in a `<span class="translation_missing">`. This custom style makes missing translations visually obvious during development so they are caught before reaching production.

```scss
.translation_missing {
  color: red;
  font-weight: bold;
  border: 3px dashed red;
}
```

This is a developer-only visual aid. In production, all i18n keys should have translations, so this style should never be visible to end users.

### DocAI Attribution Background Colors

**Why these exist:** The DocAI feature uses color-coded backgrounds to visually attribute the source of form field data. Each color represents a different attribution level, helping members understand which values were AI-extracted vs. self-reported.

```scss
.bg-attribution-primary {
  background-color: color("blue-cool-5v") !important;
}

.bg-attribution-gold {
  background-color: color("gold-5v") !important;
}

.bg-attribution-green {
  background-color: color("green-cool-5v") !important;
}

.bg-attribution-error {
  background-color: color("red-cool-5v") !important;
}
```

| Class | Color Token | Meaning |
|---|---|---|
| `bg-attribution-primary` | `blue-cool-5v` | Self-reported data (member entered it) |
| `bg-attribution-gold` | `gold-5v` | AI-assisted data (extracted by DocAI) |
| `bg-attribution-green` | `green-cool-5v` | AI-extracted, then edited by the member |
| `bg-attribution-error` | `red-cool-5v` | AI-rejected data (low confidence or errors) |

A shared rule ensures that nested elements within attribution-colored containers inherit the transparent background, while form inputs remain white for readability:

```scss
[class*="bg-attribution-"] {
  *:not(svg):not(use) {
    background-color: transparent !important;
    background: transparent !important;
  }

  .usa-input,
  .usa-select {
    background-color: white !important;
  }
}
```

**Usage in templates:**

```erb
<div class="bg-attribution-gold border-1px border-gold radius-md padding-2">
  <label class="usa-label"><%= t(".pay_amount") %></label>
  <%= f.text_field :pay_amount, class: "usa-input" %>
</div>
```

The combination of `bg-attribution-{color}` with `border-1px border-{color}` creates a visually distinct "tinted card" that communicates data provenance at a glance.

### DocAI Non-Tile Checkbox

**Why this exists:** USWDS tile-style checkboxes (with a card-like border and background) are used for most checkbox groups in OSCER. However, the DocAI opt-in checkbox needs to look like a standard checkbox without tile styling. Since the USWDS tile variant applies styles via the same CSS classes, this custom class strips the tile appearance.

```scss
.doc-ai-skip-checkbox {
  .usa-checkbox__label {
    background-color: transparent;
    border: none;
    border-radius: 0;
    padding: units(1) 0 units(1) units(5);
    box-shadow: none;
  }

  .usa-checkbox__label::before {
    box-shadow: 0 0 0 2px #1b1b1b;
    border-radius: 2px;
    background-color: transparent;
  }

  .usa-checkbox__input:checked + .usa-checkbox__label {
    background-color: transparent;
    border: none;
    box-shadow: none;
  }

  .usa-checkbox__input:hover + .usa-checkbox__label,
  .usa-checkbox__input:focus + .usa-checkbox__label {
    background-color: transparent;
    box-shadow: none;
  }
}
```

**Usage:**

```erb
<div class="doc-ai-skip-checkbox">
  <div class="usa-checkbox">
    <%= f.check_box :skip_doc_ai, class: "usa-checkbox__input" %>
    <%= f.label :skip_doc_ai, t(".skip_doc_ai"), class: "usa-checkbox__label" %>
  </div>
</div>
```

### Exemption Screener Override

The exemption screener uses content that may have specific formatting needs, so the balanced/pretty text wrapping is reset to `auto`:

```scss
div.exemption-screener {
  h1, h2, p {
    text-wrap: auto;
  }
}
```

### Scanning Animation

A CSS keyframe animation used for the DocAI document scanning progress indicator:

```scss
@keyframes scanning-progress {
  0% { width: 20%; }
  100% { width: 80%; }
}
```

---

## Color Token System

USWDS uses a design token system for colors. Tokens are named strings that map to specific color values. In OSCER, colors are always referenced by their token name -- never by raw hex values.

### Using Color Tokens in SCSS

When writing custom SCSS in `application.scss`, use the `color()` function:

```scss
// Correct -- uses USWDS token
background-color: color("blue-cool-5v");
color: color("base-dark");
border-color: color("gold-5v");

// WRONG -- never use raw hex
background-color: #2491ff;    // Don't do this
color: #565c65;               // Don't do this
```

### Using Color Tokens in Templates

In ERB templates, use the USWDS utility classes that correspond to color tokens:

```erb
<%# Text color %>
<span class="text-primary">Primary blue text</span>
<span class="text-base-dark">Dark gray text</span>
<span class="text-error">Error red text</span>

<%# Background color %>
<div class="bg-base-lightest">Light gray background</div>
<div class="bg-primary-lighter">Light blue background</div>

<%# Border color %>
<div class="border-1px border-gold">Gold border</div>
<div class="border-2px border-error">Red error border</div>
```

### Common Color Tokens Used in OSCER

| Token | Approximate Color | Typical Usage |
|---|---|---|
| `primary` | Blue (#005ea2) | Links, primary buttons, active states |
| `base` | Gray (#71767a) | Secondary text |
| `base-dark` | Dark gray (#565c65) | Emphasized secondary text |
| `base-light` | Light gray (#a9aeb1) | Disabled text, placeholders |
| `base-lightest` | Very light gray (#f0f0f0) | Page backgrounds, card backgrounds |
| `base-lighter` | Light gray (#dfe1e2) | Borders, dividers |
| `ink` | Near-black (#1b1b1b) | Default text color |
| `white` | White (#ffffff) | Card backgrounds, button text |
| `error` | Red (#b50909) | Error messages, required indicators |
| `warning` | Yellow/orange (#e5a000) | Warning messages |
| `success` | Green (#00a91c) | Success messages, confirmation |
| `info` | Blue (#00bde3) | Informational messages |
| `gold` | Gold (#ffbe2e) | Tags, attribution (DocAI) |
| `green` | Green (#04c585) | Tags, attribution (DocAI) |
| `blue-cool-5v` | Light blue tint | Attribution background (self-reported) |
| `gold-5v` | Light gold tint | Attribution background (AI-assisted) |
| `green-cool-5v` | Light green tint | Attribution background (AI + member edits) |
| `red-cool-5v` | Light red tint | Attribution background (AI rejected) |

**USWDS reference:** [designsystem.digital.gov/design-tokens/color/](https://designsystem.digital.gov/design-tokens/color/)

---

## Responsive Design Patterns

### Breakpoint Prefixes

USWDS uses a mobile-first approach. The default (unprefixed) styles apply to all screen sizes. Prefixed variants override at larger breakpoints:

| Prefix | Breakpoint | Target Devices |
|---|---|---|
| *(none)* | 0px+ | All devices (mobile-first base) |
| `tablet:` | 640px+ | Tablets and larger |
| `desktop:` | 1024px+ | Desktops and larger |

### Common Responsive Patterns

#### Stack on Mobile, Side-by-Side on Tablet

```erb
<div class="grid-row grid-gap">
  <div class="grid-col-12 tablet:grid-col-6">Left content</div>
  <div class="grid-col-12 tablet:grid-col-6">Right content</div>
</div>
```

#### Hide on Mobile, Show on Desktop

```erb
<div class="display-none desktop:display-block">
  This content is only visible on desktop screens.
</div>
```

#### Responsive Flex Direction

```erb
<%# Vertical stack on mobile, horizontal row on tablet %>
<div class="display-flex flex-column tablet:flex-row gap-2">
  <div>First</div>
  <div>Second</div>
</div>
```

#### Responsive Navigation Spacing

The sidenav layout uses responsive margins to add spacing below the nav on mobile (when it stacks above content) but removes it on tablet+ (when it sits beside content):

```erb
<nav class="tablet:grid-col-4 desktop:grid-col-3 margin-bottom-4 tablet:margin-bottom-0">
```

#### Responsive Column Widths

The content column width can change across breakpoints:

```erb
<%# 4 columns on tablet, 3 columns on desktop (used for sidenav) %>
<nav class="tablet:grid-col-4 desktop:grid-col-3">

<%# 8 columns on tablet, 9 columns on desktop (used for main content with sidenav) %>
<div class="tablet:grid-col-8 desktop:grid-col-9">
```

---

## SCSS Best Practices

### Always Use USWDS Token Functions

When writing custom SCSS, use USWDS functions instead of raw values:

```scss
// Spacing -- use units()
margin-top: units(3);        // Correct: 1.5rem
margin-top: 1.5rem;          // Wrong: raw value
margin-top: 24px;            // Wrong: raw px value

// Colors -- use color()
color: color("primary");     // Correct
color: #005ea2;              // Wrong: raw hex

// Font size -- use font-size()
font-size: font-size("sans", "lg");    // Correct
font-size: 1.22rem;                    // Wrong: raw value
```

### Never Use Tailwind Classes

OSCER uses USWDS, not Tailwind. The class naming conventions look similar but are different systems. Do not use Tailwind classes like `text-blue-500`, `p-4`, `flex`, `items-center`, etc.

| Tailwind (WRONG) | USWDS (CORRECT) |
|---|---|
| `p-4` | `padding-4` |
| `flex` | `display-flex` |
| `items-center` | `flex-align-center` |
| `justify-between` | `flex-justify` |
| `text-blue-500` | `text-primary` |
| `bg-gray-100` | `bg-base-lightest` |
| `rounded-lg` | `radius-lg` |
| `font-bold` | `text-bold` |

### Prefer Utility Classes Over Custom SCSS

Before writing custom SCSS, check if a USWDS utility class already exists for what you need. Custom SCSS should only be written when:

1. No USWDS utility class covers the need (like `gap` for flexbox)
2. The styling is component-specific and complex (like the DocAI attribution system)
3. The styling involves animations or pseudo-elements

### Keep Custom Styles in `application.scss`

All custom OSCER styles live in `app/assets/stylesheets/application.scss`. This keeps custom CSS centralized and easy to audit. There are no component-specific CSS files scattered throughout the codebase.

### Use `!important` Sparingly in Custom Styles

The USWDS theme sets `$utilities-use-important: true`, so all USWDS utility classes already use `!important`. Custom styles should only use `!important` when they need to override USWDS component styles (as the attribution backgrounds do). In most cases, specificity through class nesting is sufficient.

---

## Quick Reference: Choosing the Right Approach

| Need | Approach |
|---|---|
| Spacing (margin, padding) | USWDS utility class: `margin-top-4`, `padding-x-2` |
| Text color | USWDS utility class: `text-primary`, `text-error` |
| Background color | USWDS utility class: `bg-base-lightest`, `bg-white` |
| Layout (grid) | USWDS grid classes: `grid-container`, `grid-row`, `grid-col-{n}` |
| Layout (flexbox) | USWDS flex utilities + OSCER `gap-{n}` |
| Button styling | USWDS component class: `usa-button`, `usa-button--outline` |
| Form inputs | USWDS component classes: `usa-input`, `usa-select`, `usa-checkbox` |
| Responsive behavior | USWDS breakpoint prefix: `tablet:`, `desktop:` |
| Custom component style | SCSS in `application.scss` using `color()`, `units()`, `font-size()` |
| DocAI data attribution | Custom `bg-attribution-{color}` class + `border-{color}` |

---

## References

- [USWDS Design Tokens](https://designsystem.digital.gov/design-tokens/)
- [USWDS Utilities](https://designsystem.digital.gov/utilities/)
- [USWDS Components](https://designsystem.digital.gov/components/overview/)
- [USWDS Settings](https://designsystem.digital.gov/documentation/settings/)
- [USWDS Color Tokens](https://designsystem.digital.gov/design-tokens/color/)
- [USWDS Spacing Units](https://designsystem.digital.gov/design-tokens/spacing-units/)
- [USWDS Typography](https://designsystem.digital.gov/design-tokens/typesetting/)
- [Public Sans Typeface](https://public-sans.digital.gov/)
