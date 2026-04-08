# Design System: Stimulus Controllers

This document covers the Stimulus controllers used in the OSCER application, including architecture decisions, detailed documentation of each controller, source code walkthrough, usage examples, and integration patterns.

> **Machine-readable version**: `.claude/rules/design-system-stimulus.md` contains the compact rule set consumed by AI tooling. This document is the expanded human-readable reference.

---

## Table of Contents

- [Architecture](#architecture)
- [Controller Reference](#controller-reference)
  - [exemption-screener](#exemption-screener)
  - [file-list](#file-list)
  - [auto-refresh](#auto-refresh)
  - [document-preview](#document-preview)
  - [registrations](#registrations)
  - [sso-redirect](#sso-redirect)
  - [strata--conditional-field (Strata SDK)](#strata--conditional-field-strata-sdk)
- [Turbo Integration](#turbo-integration)
- [Adding a New Controller](#adding-a-new-controller)

---

## Architecture

### Module loading

OSCER uses **ImportMap** for JavaScript module loading. There is no webpack, esbuild, or other bundler. All Stimulus controllers are loaded as ES modules via the Rails ImportMap pipeline.

### File locations

All custom controllers live in:
```
reporting-app/app/javascript/controllers/
```

### Naming convention

File names use snake_case and automatically map to kebab-case `data-controller` values:
- `exemption_screener_controller.js` --> `data-controller="exemption-screener"`
- `file_list_controller.js` --> `data-controller="file-list"`
- `auto_refresh_controller.js` --> `data-controller="auto-refresh"`
- `document_preview_controller.js` --> `data-controller="document-preview"`

### Auto-registration

Controllers are eager-loaded via `@hotwired/stimulus-loading`. No manual registration step is needed. Simply creating a file in the controllers directory makes it available.

### USWDS JavaScript

USWDS ships its own JavaScript (`uswds-init.min.js` in `<head>`, `uswds.min.js` at body bottom). Stimulus controllers **supplement** USWDS -- they do not replace it. USWDS handles its own component behavior (date pickers, accordions, modals); Stimulus handles OSCER-specific interactivity.

---

## Controller Reference

### exemption-screener

**File**: `app/javascript/controllers/exemption_screener_controller.js`

**Purpose**: Prevents form submission until the user selects a radio button option. Used on the exemption screener questionnaire to enforce that a choice is made before proceeding.

#### Source code

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.submitTarget.disabled = true
  }

  enableSubmit() {
    this.submitTarget.disabled = false
  }
}
```

#### How it works

1. **On connect**: The controller finds the element marked with `data-exemption-screener-target="submit"` and disables it. This prevents the user from submitting the form before making a selection.
2. **On radio change**: When any radio button with the `change->exemption-screener#enableSubmit` action fires, the submit button is re-enabled.

The controller is intentionally simple -- it does not re-disable the button if the user somehow deselects (radio buttons cannot be deselected natively). Once any option is chosen, submission is allowed.

#### API

| Property | Value |
|---|---|
| **Targets** | `submit` -- the submit button element |
| **Actions** | `enableSubmit` -- removes `disabled` from submit target |
| **Values** | None |

#### Usage example

```erb
<%= strata_form_with(url: exemption_screener_path, data: { controller: "exemption-screener" }) do |f| %>
  <%= f.fieldset t(".legend") do %>
    <%= f.radio_button :answer, "yes", {
      label: t(".yes_answer"),
      tile: true,
      data: { action: "change->exemption-screener#enableSubmit" }
    } %>
    <%= f.radio_button :answer, "no", {
      label: t(".no_answer"),
      tile: true,
      data: { action: "change->exemption-screener#enableSubmit" }
    } %>
  <% end %>

  <%= f.submit t(".submit"), data: { exemption_screener_target: "submit" } %>
<% end %>
```

---

### file-list

**File**: `app/javascript/controllers/file_list_controller.js`

**Purpose**: Manages a list of file cards in the document upload UI. Allows removing individual file cards and keeps the URL query parameters in sync with the visible files.

#### Source code

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  remove(event) {
    const card = event.target.closest("[data-file-list-target='card']")
    if (!card) return

    const id = card.dataset.id

    if (id) {
      const url = new URL(window.location.href)
      const ids = url.searchParams.getAll("ids[]")
      url.searchParams.delete("ids[]")
      ids.filter(i => i !== id).forEach(i => url.searchParams.append("ids[]", i))
      window.history.replaceState({}, "", url.toString())
    }

    card.remove()
  }
}
```

#### How it works

1. **Card identification**: Each file card is a DOM element with `data-file-list-target="card"` and a `data-id` attribute containing the file/document ID.
2. **Remove action**: When the remove button is clicked, the controller uses `event.target.closest()` to find the nearest card ancestor. This means the button can be nested at any depth within the card.
3. **URL parameter sync**: The controller reads all `ids[]` query parameters from the current URL, removes the ID of the card being deleted, and updates the browser URL using `history.replaceState`. This ensures that if the page is refreshed or a form is submitted, the removed file is not re-included.
4. **DOM removal**: The card element is removed from the DOM.

#### API

| Property | Value |
|---|---|
| **Targets** | `card` -- each file card element (must have `data-id` attribute) |
| **Actions** | `remove` -- removes the card and updates URL params |
| **Values** | None |

#### Usage example

```erb
<div data-controller="file-list">
  <h2><%= t(".selected_files") %></h2>

  <% @documents.each do |doc| %>
    <div data-file-list-target="card" data-id="<%= doc.id %>"
         class="border-1px border-base-lighter radius-md padding-2 margin-bottom-2">
      <div class="display-flex flex-justify flex-align-center">
        <span><%= doc.filename %></span>
        <button type="button"
                data-action="click->file-list#remove"
                class="usa-button usa-button--unstyled text-error">
          <%= t(".remove_file") %>
        </button>
      </div>
    </div>
  <% end %>
</div>
```

---

### auto-refresh

**File**: `app/javascript/controllers/auto_refresh_controller.js`

**Purpose**: Polls a Turbo Frame at a configurable interval to check for server-side status updates. Self-terminates when the server sets `active` to `false`. Used for the Document AI processing status screen, where the server processes documents asynchronously and the UI polls for completion.

#### Source code

```javascript
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    active: Boolean,
    interval: { type: Number, default: 5000 }
  }

  disconnect() {
    this.stopPolling()
  }

  activeValueChanged() {
    if (this.activeValue) {
      this.startPolling()
    } else {
      this.stopPolling()
      if (this.hasPolled) {
        this.hasPolled = false
        Turbo.visit(window.location.href)
      }
    }
  }

  startPolling() {
    if (this.pollTimer) return
    this.pollTimer = setInterval(() => {
      this.hasPolled = true
      this.element.src = window.location.href
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }
}
```

#### How it works

1. **No explicit `connect()` method**: Stimulus automatically calls `activeValueChanged()` when the controller connects and the value is read from the DOM. This handles both initial setup and subsequent updates.
2. **Polling start**: When `active` is `true`, `startPolling()` sets up a `setInterval` that reassigns the Turbo Frame's `src` attribute to the current page URL. This triggers Turbo to fetch the frame content from the server.
3. **Polling stop**: When the server response changes `active` to `false` (via updated `data-auto-refresh-active-value` in the returned HTML), `activeValueChanged()` fires again, stops the timer, and triggers a full-page `Turbo.visit`. The full-page visit is necessary so that flash messages (rendered outside the Turbo Frame) become visible.
4. **Guard against duplicate timers**: `startPolling()` checks for an existing `pollTimer` before creating a new interval.
5. **Cleanup on disconnect**: The `disconnect()` lifecycle method clears the interval to prevent memory leaks if the element is removed from the DOM.

#### API

| Property | Value |
|---|---|
| **Targets** | None |
| **Actions** | None (behavior is value-driven) |
| **Values** | `active` (Boolean) -- whether to poll; `interval` (Number, default 5000) -- milliseconds between polls |

#### Usage example

```erb
<%# The Turbo Frame polls itself when active is true %>
<turbo-frame id="processing-status"
  data-controller="auto-refresh"
  data-auto-refresh-active-value="<%= @polling_active %>"
  data-auto-refresh-interval-value="5000"
  src="<%= doc_ai_upload_status_document_staging_path %>">

  <% if @polling_active %>
    <div class="display-flex flex-column flex-align-center padding-y-6">
      <%= uswds_icon("hourglass_empty", size: 4, css_class: "text-primary") %>
      <h2><%= t(".processing.title") %></h2>
      <p><%= t(".processing.body") %></p>
      <p class="text-base"><%= t(".processing.time_warning") %></p>
    </div>
  <% else %>
    <%# Render results -- the full-page Turbo.visit will fire %>
  <% end %>
</turbo-frame>
```

**Server-side pattern**: The controller action renders the same template on each poll. When processing is complete, it sets `@polling_active = false` in the response, which updates the `data-auto-refresh-active-value` attribute, causing the controller to stop polling and trigger a full-page navigation.

---

### document-preview

**File**: `app/javascript/controllers/document_preview_controller.js`

**Purpose**: Toggles between a document table view and a preview pane. Handles three content types -- PDFs (shown in an iframe), images (shown in an `<img>` tag), and other file types (shown as a download link). Also manages the visibility of activity-specific prefill forms.

#### Source code

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "table", "previewArea", "prefillForm",
    "iframe", "image", "fallback", "fallbackLink", "heading"
  ]

  select(event) {
    event.preventDefault()
    const { url, filename, contentType, activityId } = event.params
    this.#updateHeading(filename)
    this.#showPrefillForm(activityId)
    this.#showPreview(url, filename, contentType)
    this.#openPreviewArea()
  }

  close() {
    this.previewAreaTarget.classList.add("display-none")
    this.tableTarget.classList.remove("display-none")
  }

  // Private methods handle heading interpolation, prefill form
  // toggling, content-type detection, and preview area visibility.
}
```

#### How it works

1. **`select` action**: Extracts four parameters from the clicked element's `data-document-preview-*-param` attributes: `url`, `filename`, `contentType`, and `activityId`.
2. **Heading update**: Uses a `data-template` attribute on the heading target to interpolate the filename (e.g., `"Preview: %{filename}"` becomes `"Preview: payslip.pdf"`).
3. **Prefill form toggle**: If there are multiple prefill forms (one per activity), the controller hides all of them and shows only the one whose `data-activity-id` matches the selected document's `activityId`.
4. **Content-type routing**:
   - `application/pdf` --> Sets `iframe.src` to the document URL and shows the iframe.
   - `image/*` --> Sets `img.src` to the document URL and shows the image element.
   - Everything else --> Shows a download link pointing to the document URL.
5. **View toggle**: Hides the table and shows the preview area. The `close` action reverses this.

#### API

| Property | Value |
|---|---|
| **Targets** | `table`, `previewArea`, `prefillForm`, `iframe`, `image`, `fallback`, `fallbackLink`, `heading` |
| **Actions** | `select` -- opens preview for a document; `close` -- returns to table view |
| **Params** | `url` (String), `filename` (String), `contentType` (String), `activityId` (String) |
| **Values** | None |

#### Usage example

```erb
<div data-controller="document-preview">
  <%# Document table view %>
  <div data-document-preview-target="table">
    <table class="usa-table usa-table--striped width-full">
      <thead>
        <tr>
          <th scope="col"><%= t(".col_filename") %></th>
          <th scope="col"><%= t(".col_actions") %></th>
        </tr>
      </thead>
      <tbody>
        <% @documents.each do |doc| %>
          <tr>
            <td><%= doc.filename %></td>
            <td>
              <button data-action="click->document-preview#select"
                data-document-preview-url-param="<%= url_for(doc.file) %>"
                data-document-preview-filename-param="<%= doc.filename %>"
                data-document-preview-content-type-param="<%= doc.content_type %>"
                data-document-preview-activity-id-param="<%= doc.activity_id %>"
                class="usa-button usa-button--unstyled">
                <%= t(".preview") %>
              </button>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# Preview area (hidden by default) %>
  <div data-document-preview-target="previewArea" class="display-none">
    <div class="display-flex flex-justify flex-align-center margin-bottom-2">
      <h2 data-document-preview-target="heading"
          data-template="<%= t('.preview_heading_template') %>"></h2>
      <button data-action="click->document-preview#close"
              class="usa-button usa-button--outline">
        <%= t(".close_preview") %>
      </button>
    </div>

    <%# PDF preview %>
    <iframe data-document-preview-target="iframe"
            class="display-none width-full"
            style="height: 600px;"
            data-title-template="<%= t('.iframe_title_template') %>">
    </iframe>

    <%# Image preview %>
    <img data-document-preview-target="image"
         class="display-none width-full"
         data-alt-template="<%= t('.image_alt_template') %>">

    <%# Fallback download link %>
    <div data-document-preview-target="fallback" class="display-none">
      <p><%= t(".cannot_preview") %></p>
      <a data-document-preview-target="fallbackLink"
         class="usa-button">
        <%= t(".download") %>
      </a>
    </div>

    <%# Activity-specific prefill forms %>
    <% @activities.each do |activity| %>
      <div data-document-preview-target="prefillForm"
           data-activity-id="<%= activity.id %>"
           class="display-none">
        <%# Prefill form content for this activity %>
      </div>
    <% end %>
  </div>
</div>
```

---

### registrations

**File**: `app/javascript/controllers/registrations_controller.js`

**Purpose**: Handles registration form behavior including password visibility toggling and client-side validation.

This controller is used on the Devise registration pages. It is a standard Stimulus controller -- see the source file for implementation details.

---

### sso-redirect

**File**: `app/javascript/controllers/sso_redirect_controller.js`

**Purpose**: Handles the SSO redirect flow. When staff users land on the SSO redirect page, this controller manages the automatic redirect to the identity provider.

This controller is used on the SSO login flow pages. See the source file for implementation details.

---

### strata--conditional-field (Strata SDK)

**Purpose**: Show or hide form sections based on radio button selection. This is a Strata SDK controller, not an OSCER custom controller. It is typically used indirectly through the `f.conditional` FormBuilder method rather than being wired up manually.

#### API

| Property | Value |
|---|---|
| **Values** | `source` (String) -- the radio button `name` attribute; `match` (Array) -- trigger values that show the content; `clear` (Boolean) -- whether to clear hidden inputs when content is hidden |
| **Behavior** | Shows content when the radio with the matching `name` has a selected value in the `match` list. Optionally clears input values when hiding. |

#### Usage example (via FormBuilder)

```erb
<%= strata_form_with(model: @model) do |f| %>
  <%= f.fieldset t(".status_legend") do %>
    <%= f.radio_button :status, "active", { label: t(".active"), tile: true } %>
    <%= f.radio_button :status, "inactive", { label: t(".inactive"), tile: true } %>
  <% end %>

  <%# This content is shown only when status is "active" %>
  <%= f.conditional :status, eq: "active" do %>
    <%= f.text_field :start_date, label: t(".start_date") %>
  <% end %>

  <%# With clear: inputs are reset when hidden %>
  <%= f.conditional :status, eq: ["active", "pending"], clear: true do %>
    <%= f.text_field :notes, label: t(".notes") %>
  <% end %>

  <%= f.submit t(".save"), big: true %>
<% end %>
```

The `f.conditional` helper generates the appropriate `data-controller="strata--conditional-field"` attributes and value bindings automatically.

---

## Turbo Integration

OSCER uses Hotwire (Turbo + Stimulus) but with specific configuration:

### Turbo Drive

**Turbo Drive is disabled globally.** Link clicks trigger full-page navigations, not Turbo Drive visits. This simplifies debugging and avoids issues with USWDS JavaScript initialization.

### Turbo Frames

**Turbo Frames are enabled** for partial page updates. The `auto-refresh` controller is the primary example -- it uses a `<turbo-frame>` to poll for status updates without reloading the entire page.

### Disabling Turbo on forms

When a form should not use Turbo (full-page submission):

```erb
<%= strata_form_with(url: path, data: { turbo: false }) do |f| %>
  <%# This form submits as a regular HTTP request %>
<% end %>
```

### Event handling

Always use Stimulus `data-action` attributes for event handling. Never use inline `onclick` handlers:

```erb
<%# CORRECT %>
<button data-action="click->file-list#remove">Remove</button>

<%# WRONG -- do not use inline handlers %>
<button onclick="removeFile()">Remove</button>
```

---

## Adding a New Controller

### Step 1: Create the file

Create a new file in `app/javascript/controllers/`:

```javascript
// app/javascript/controllers/my_feature_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = { url: String }

  connect() {
    // Called when the controller is attached to the DOM
  }

  doSomething() {
    // Action method -- triggered by data-action
  }
}
```

### Step 2: Use in ERB

The controller is auto-registered via ImportMap. Reference it by kebab-case name:

```erb
<div data-controller="my-feature"
     data-my-feature-url-value="<%= some_url %>">
  <span data-my-feature-target="output"></span>
  <button data-action="click->my-feature#doSomething">
    <%= t(".do_something") %>
  </button>
</div>
```

### Step 3: No manual registration needed

Unlike setups with webpack or esbuild, there is no index file to update. The `@hotwired/stimulus-loading` package handles eager loading of all controllers in the directory.

### Guidelines for new controllers

- **Keep controllers small and focused.** Each controller should handle one specific interaction pattern.
- **Use targets** for elements the controller needs to reference. Do not use `querySelector` when a target will do.
- **Use values** for configuration data passed from the server. Values are typed (Boolean, Number, String, Array, Object) and trigger `{name}ValueChanged()` callbacks automatically.
- **Use params** for per-element data passed through action attributes (`data-{controller}-{name}-param`).
- **Prefer USWDS utility classes** (`display-none`, `display-block`) over direct `style` manipulation for visibility toggling.
- **Never manipulate USWDS component internals.** USWDS manages its own component JS. If you need to enhance a USWDS component, wrap it in your own controller and interact through the DOM API.
- **Always use `t()` for any text** the controller might inject into the DOM. Use `data-template` attributes with `%{variable}` placeholders (as seen in `document-preview`) rather than hardcoded strings.
