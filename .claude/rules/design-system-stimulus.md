# Design System: Stimulus Controllers

## Architecture

- **Module loading**: ImportMap (no webpack/esbuild)
- **Controllers location**: `app/javascript/controllers/`
- **Naming**: `foo_bar_controller.js` → `data-controller="foo-bar"`
- **Auto-registration**: Controllers are eager-loaded via `@hotwired/stimulus-loading` — no manual registration needed
- **USWDS JS**: Loaded separately (`uswds-init.min.js` in head, `uswds.min.js` at body bottom) — Stimulus supplements, does not replace

## Available Controllers

### `exemption-screener`
**Purpose**: Disable submit button until a radio option is selected.

```erb
<%= strata_form_with(url: path, data: { controller: "exemption-screener" }) do |f| %>
  <%= f.radio_button :answer, "yes", {
    label: t(".yes"),
    data: { action: "change->exemption-screener#enableSubmit" }
  } %>
  <%= f.submit t(".submit"), data: { exemption_screener_target: "submit" } %>
<% end %>
```

| | |
|---|---|
| **Targets** | `submit` |
| **Actions** | `enableSubmit` |
| **Behavior** | `submit` target disabled on connect, enabled on radio change |

### `file-list`
**Purpose**: Remove file cards from an upload list and update URL params.

```erb
<div data-controller="file-list">
  <div data-file-list-target="card" data-id="<%= doc.id %>">
    <button data-action="click->file-list#remove">Remove</button>
  </div>
</div>
```

| | |
|---|---|
| **Targets** | `card` |
| **Actions** | `remove` |
| **Behavior** | Removes card element, updates `ids[]` URL params |

### `auto-refresh`
**Purpose**: Poll a Turbo Frame at a configurable interval. Self-terminates when server sets `active` to false.

```erb
<turbo-frame id="status-frame"
  data-controller="auto-refresh"
  data-auto-refresh-active-value="<%= @polling_active %>"
  data-auto-refresh-interval-value="5000">
</turbo-frame>
```

| | |
|---|---|
| **Values** | `active` (Boolean), `interval` (Number, default: 5000ms) |
| **Behavior** | Polls current URL when `active=true`, stops + Turbo visits on `active=false` |

### `document-preview`
**Purpose**: Toggle between a document table and a preview pane (PDF, image, or fallback).

```erb
<div data-controller="document-preview">
  <div data-document-preview-target="table">
    <button data-action="click->document-preview#select"
      data-document-preview-url-param="<%= url %>"
      data-document-preview-filename-param="<%= name %>"
      data-document-preview-content-type-param="application/pdf"
      data-document-preview-activity-id-param="<%= id %>">
      Preview
    </button>
  </div>
  <div data-document-preview-target="previewArea" class="display-none">
    <h2 data-document-preview-target="heading" data-template="Preview: %{filename}"></h2>
    <iframe data-document-preview-target="iframe" class="display-none"></iframe>
    <img data-document-preview-target="image" class="display-none">
    <div data-document-preview-target="fallback" class="display-none">
      <a data-document-preview-target="fallbackLink">Download</a>
    </div>
    <button data-action="click->document-preview#close">Close</button>
  </div>
</div>
```

| | |
|---|---|
| **Targets** | `table`, `previewArea`, `prefillForm`, `iframe`, `image`, `fallback`, `fallbackLink`, `heading` |
| **Actions** | `select`, `close` |
| **Params** | `url`, `filename`, `contentType`, `activityId` |
| **Behavior** | Shows PDF in iframe, images in img tag, other types show download link |

### `registrations`
**Purpose**: Registration form behavior (password visibility, validation).

| | |
|---|---|
| **Location** | `app/javascript/controllers/registrations_controller.js` |

### `sso-redirect`
**Purpose**: Handle SSO redirect flow.

| | |
|---|---|
| **Location** | `app/javascript/controllers/sso_redirect_controller.js` |

### `strata--conditional-field` (Strata SDK)
**Purpose**: Show/hide form sections based on radio button selection. Used via `f.conditional` in FormBuilder.

```erb
<%# Typically used through FormBuilder, not directly: %>
<%= f.conditional :my_attr, eq: "yes" do %>
  <%= f.text_field :follow_up, label: t(".follow_up") %>
<% end %>
```

| | |
|---|---|
| **Values** | `source` (radio name attr), `match` (trigger values), `clear` (Boolean) |
| **Behavior** | Shows content when radio matches, optionally clears inputs on hide |

## Turbo Integration

- **Turbo Drive**: Disabled globally (full page navigation on link clicks)
- **Turbo Frames**: Enabled for partial page updates
- **Disable Turbo on forms**: `data: { turbo: false }` in `strata_form_with`
- Stimulus controllers work alongside Turbo — use `data-action` for events, not `onclick`

## Adding New Controllers

1. Create `app/javascript/controllers/my_feature_controller.js`
2. Import from `@hotwired/stimulus` and export default class
3. Auto-registered via importmap eager loading — no manual step needed

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = { url: String }

  connect() { /* setup */ }
  doSomething() { /* action */ }
}
```
