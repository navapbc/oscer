# Design System: Styles

## Critical Rules

- ALWAYS use USWDS utility classes — NEVER raw hex colors or arbitrary CSS values
- NEVER use Tailwind classes — this project uses USWDS
- Custom styles go in `app/assets/stylesheets/application.scss` using USWDS SCSS tokens

## Typography

- **Font**: Public Sans (`$theme-font-type-sans: "public-sans"`)
- **Heading sizes**: H1 = `2xl`, H2 = `lg`, H3 = `md`
- **Semibold weight**: 600
- **Text wrapping**: Headings/labels use `text-wrap: balance`, body text uses `text-wrap: pretty`

## USWDS Utility Classes Quick Reference

### Spacing
```
margin-{top/bottom/left/right/x/y}-{0-10}
padding-{top/bottom/left/right/x/y}-{0-10}
margin-y-6        ← vertical margin
padding-x-205     ← horizontal padding (2.5 units)
```

### Display & Flex
```
display-flex  display-block  display-none  display-inline-block
flex-row  flex-column  flex-fill  flex-auto
flex-justify  flex-justify-center  flex-justify-end
flex-align-center  flex-align-start  flex-align-end  flex-align-self-center
```

### Typography
```
font-sans-{2xs/xs/sm/md/lg/xl/2xl/3xl}
text-bold  text-semibold  text-normal  text-italic
text-center  text-right  text-left
text-no-wrap  text-pre-wrap
```

### Colors (text)
```
text-primary  text-base  text-base-dark  text-base-light
text-error  text-warning  text-success  text-info
text-gold  text-green  text-white
```

### Colors (background)
```
bg-white  bg-base-lightest  bg-base-lighter  bg-base-light
bg-primary  bg-primary-lighter  bg-error-lighter
```

### Border
```
border-{1px/2px/05/1/105/2/205/3}
border-{top/bottom/left/right}-{1px/2px/05/1}
border-primary  border-gold  border-green  border-error  border-base-lighter
radius-md  radius-lg
```

### Width & Size
```
width-full  maxw-tablet  minh-viewport
height-0  width-0
```

### Visibility
```
display-none  desktop:display-block     ← hide on mobile, show on desktop
opacity-0  position-absolute  z-bottom  ← visually hidden (honeypot)
usa-sr-only                              ← screen-reader only
```

## USWDS Component Classes

### Buttons
```erb
<%= link_to t(".label"), path, class: "usa-button" %>
<%= link_to t(".label"), path, class: "usa-button usa-button--outline" %>
<%= link_to t(".label"), path, class: "usa-button usa-button--big" %>
<%= link_to t(".label"), path, class: "usa-button usa-button--unstyled" %>
<div class="usa-button-group" role="group" aria-label="...">
```

### Tags
```erb
<span class="usa-tag"><%= status %></span>
<span class="usa-tag bg-gold text-ink"><%= custom_tag %></span>
```

### Lists
```erb
<ul class="usa-list">
<ul class="usa-list usa-list--unstyled">
<ol class="usa-process-list">
```

### Summary Box
```erb
<div class="usa-summary-box" role="region" aria-labelledby="summary-heading">
  <div class="usa-summary-box__body">
    <h2 class="usa-summary-box__heading" id="summary-heading">...</h2>
    <div class="usa-summary-box__text">...</div>
  </div>
</div>
```

### Section
```erb
<section class="usa-section">
<section class="usa-section usa-section--light">
<section class="usa-section padding-y-4">  <%# reduced padding %>
```

## Custom OSCER Utilities

### Gap (flexbox)
```
gap-0  gap-1  gap-2  gap-3  gap-4  gap-5  gap-6  gap-7  gap-8  gap-9  gap-10
```
Maps to USWDS spacing units. Use with `display-flex`.

### DocAI Attribution Backgrounds
```
bg-attribution-primary   ← blue-cool-5v (self-reported)
bg-attribution-gold      ← gold-5v (AI-assisted)
bg-attribution-green     ← green-cool-5v (AI + member edits)
bg-attribution-error     ← red-cool-5v (AI rejected)
```
Use with `border-1px border-{color}` for full attribution styling.

### DocAI Non-Tile Checkbox
```
doc-ai-skip-checkbox     ← removes tile styling from checkbox
```

### Developer Tooling
```
translation_missing      ← auto-applied by Rails when i18n key missing (red dashed border)
```

## Responsive Breakpoint Prefixes

- Default: all screen sizes
- `tablet:` — 640px and above
- `desktop:` — 1024px and above

```erb
<%# Stack on mobile, side-by-side on tablet %>
<div class="grid-col-12 tablet:grid-col-6">

<%# Hide on mobile, show on desktop %>
<div class="display-none desktop:display-block">
```

## Color Tokens (SCSS only)

When writing custom SCSS, use USWDS token functions — NEVER raw hex:

```scss
color: color("blue-cool-5v");
background-color: color("gold-5v");
gap: units(2);
font-size: font-size("sans", "lg");
```
