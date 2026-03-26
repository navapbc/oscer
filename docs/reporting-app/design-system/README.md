# OSCER Design System Documentation

The OSCER design system is built on the **U.S. Web Design System (USWDS) 3.7.1**, extended through the **Strata SDK** component library and OSCER-specific ViewComponents. It powers a Rails 7.2 application that serves both member-facing (community engagement reporting) and staff-facing (case management) interfaces.

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **CSS framework** | USWDS 3.7.1 | Utility classes, component styles, design tokens |
| **Component library** | Strata SDK | Rails ViewComponents wrapping USWDS (forms, tables, accordions, task lists) |
| **Custom components** | OSCER ViewComponents | App-specific components (`AlertComponent`, icon helpers, attribution) |
| **Form builder** | `Strata::FormBuilder` | USWDS-aware form builder via `strata_form_with` |
| **JavaScript** | Stimulus (Hotwire) | Lightweight controllers for interactive behavior |
| **Module loading** | ImportMap | ES module loading without a bundler |
| **Styling** | SCSS + USWDS tokens | Custom styles using USWDS SCSS token functions |
| **Internationalization** | Rails i18n | `en` and `es-US` locales with lazy lookup |
| **Templates** | ERB | Server-rendered HTML with USWDS classes |

---

## Documentation Files

### Reference guides

| Document | Description |
|---|---|
| [Components](../../../.claude/rules/design-system-components.md) | ViewComponent reference: `AlertComponent`, `Strata::US::TableComponent`, `Strata::US::AccordionComponent`, icon helpers, feature flags in views |
| [Forms](../../../.claude/rules/design-system-forms.md) | `strata_form_with` FormBuilder reference: all field methods, composite fields, conditional fields, error display, accessibility |
| [Layouts](../../../.claude/rules/design-system-layouts.md) | Layout hierarchy, yield points, USWDS grid system, navigation components, flexbox patterns, routing conventions |
| [Styles](../../../.claude/rules/design-system-styles.md) | USWDS utility class reference: spacing, display/flex, typography, colors, borders, responsive breakpoints, SCSS token functions |

### Workflow guides

| Document | Description |
|---|---|
| [Figma Mapping](figma-mapping.md) | Bidirectional mapping between USWDS Figma Kit v3 components and OSCER code. Layout translation, spacing token mapping, page type routing, common pattern translations, bounded context file locations |
| [Internationalization (i18n)](i18n.md) | Locale file organization, key naming conventions, lookup patterns, code examples, pluralization, date formatting, YAML gotchas, Figma text-to-key workflow |
| [Stimulus Controllers](stimulus.md) | Architecture overview, detailed documentation of all controllers (`exemption-screener`, `file-list`, `auto-refresh`, `document-preview`, etc.), source code walkthroughs, Turbo integration |

---

## Relationship to `.claude/rules/`

The design system documentation exists in two forms:

1. **`.claude/rules/design-system-*.md`** -- Compact machine-readable rule files. These are loaded automatically by Claude Code as context when working in the OSCER codebase. They contain the essential rules and reference tables in a token-efficient format.

2. **`docs/reporting-app/design-system/`** (this directory) -- Expanded human-readable documentation. These files contain the same information as the rules files but with additional context, explanations, real-world examples, source code walkthroughs, and workflow guidance.

The rules files are the authoritative source for AI tooling behavior. The documentation files in this directory are the authoritative source for human developers. When updating conventions, update both locations.

### Rule files

| Rule file | Corresponding documentation |
|---|---|
| `.claude/rules/design-system-components.md` | Components reference (rule file is the primary doc) |
| `.claude/rules/design-system-forms.md` | Forms reference (rule file is the primary doc) |
| `.claude/rules/design-system-layouts.md` | Layouts reference (rule file is the primary doc) |
| `.claude/rules/design-system-styles.md` | Styles reference (rule file is the primary doc) |
| `.claude/rules/design-system-figma-mapping.md` | [Figma Mapping](figma-mapping.md) |
| `.claude/rules/design-system-i18n.md` | [Internationalization](i18n.md) |
| `.claude/rules/design-system-stimulus.md` | [Stimulus Controllers](stimulus.md) |
