# Turbo Frames Polling Reference

This document provides code examples of how to use Turbo Frames and a Stimulus controller to implement auto-refreshing/polling for document processing status.

## Implementation Overview

The pattern uses:
1.  **Turbo Frame**: A `<turbo-frame>` tag that wraps the content to be updated.
2.  **Stimulus Controller**: An `auto-refresh` controller that triggers the Turbo Frame to reload at a specified interval.
3.  **Conditional Polling**: The controller is deactivated once all documents have finished processing.

## Code Examples

### 1. Initial View (`create.html.erb`)

When documents are first uploaded, this view renders the initial processing state and starts the Turbo Frame polling.

```erb:reporting-app/app/views/document_staging/create.html.erb
<% content_for :title, t(".title") %>
<%= render partial: 'application/flash' %>

<h1><%= t(".heading") %></h1>

<% if @error %>
  <div class="usa-alert usa-alert--error margin-bottom-3" role="alert">
    <div class="usa-alert__body">
      <p class="usa-alert__text"><%= @error %></p>
    </div>
  </div>
<% else %>
  <%= turbo_frame_tag "document_staging_status",
        src: lookup_document_staging_path(ids: @staged_document_ids),
        data: {
          controller: "auto-refresh",
          auto_refresh_active_value: true,
          auto_refresh_interval_value: 15000
        } do %>
    <%= render partial: "processing_status", locals: { staged_documents: @staged_documents } %>
  <% end %>
<% end %>
```

### 2. Polling Endpoint View (`lookup.html.erb`)

This view is rendered by the `lookup` action. It updates the Turbo Frame content and decides whether to continue polling.

```erb:reporting-app/app/views/document_staging/lookup.html.erb
<%= turbo_frame_tag "document_staging_status",
      data: {
        controller: "auto-refresh",
        auto_refresh_active_value: !@all_complete,
        auto_refresh_interval_value: 15000
      } do %>
  <% if @all_complete %>
    <%= render partial: "results", locals: { staged_documents: @staged_documents } %>
  <% else %>
    <%= render partial: "processing_status", locals: { staged_documents: @staged_documents } %>
  <% end %>
<% end %>
```

### 3. Processing Status Partial (`_processing_status.html.erb`)

Displays the current status of documents while they are still being processed.

```erb:reporting-app/app/views/document_staging/_processing_status.html.erb
<div class="usa-alert usa-alert--info margin-bottom-3" role="alert">
  <div class="usa-alert__body">
    <h4 class="usa-alert__heading"><%= t("document_staging.processing.title") %></h4>
    <p class="usa-alert__text"><%= t("document_staging.processing.body") %></p>
    <p class="usa-alert__text"><%= t("document_staging.processing.time_warning") %></p>
  </div>
</div>

<ul class="usa-list">
  <% staged_documents.each do |doc| %>
    <li>
      <%= doc.file.filename %>
      <span class="usa-tag"><%= doc.status.humanize %></span>
    </li>
  <% end %>
</ul>
```

### 4. Final Results Partial (`_results.html.erb`)

Displays the final results once processing is complete, including hidden fields for signed IDs.

```erb:reporting-app/app/views/document_staging/_results.html.erb
<% validated = staged_documents.select(&:validated?) %>
<% rejected = staged_documents.select(&:rejected?) %>
<% failed = staged_documents.select(&:failed?) %>

<% if validated.any? %>
  <div class="usa-alert usa-alert--success margin-bottom-3" role="alert">
    <div class="usa-alert__body">
      <p class="usa-alert__text"><%= t("document_staging.results.success", count: validated.size) %></p>
    </div>
  </div>
<% end %>

<% if rejected.any? %>
  <div class="usa-alert usa-alert--warning margin-bottom-3" role="alert">
    <div class="usa-alert__body">
      <p class="usa-alert__text"><%= t("document_staging.results.rejected", count: rejected.size) %></p>
    </div>
  </div>
<% end %>

<% if failed.any? %>
  <div class="usa-alert usa-alert--error margin-bottom-3" role="alert">
    <div class="usa-alert__body">
      <p class="usa-alert__text"><%= t("document_staging.results.failed", count: failed.size) %></p>
    </div>
  </div>
<% end %>

<ul class="usa-list">
  <% staged_documents.each do |doc| %>
    <li>
      <%= doc.file.filename %>
      <span class="usa-tag usa-tag--<%= doc.status %>"><%= doc.status.humanize %></span>
      <% if doc.doc_ai_matched_class.present? %>
        (<%= doc.doc_ai_matched_class %>)
      <% end %>
    </li>
  <% end %>
</ul>

<% if validated.any? %>
  <%= hidden_field_tag "staged_document_signed_ids[]", nil, id: nil %>
  <% validated.each do |doc| %>
    <%= hidden_field_tag "staged_document_signed_ids[]", doc.file.blob.signed_id, id: nil %>
  <% end %>
<% end %>
```

## Redirect After Upload

As noted in the `DocumentStagingController#create` (see TODO on line 12), after documents are submitted for staging, the user should be redirected to a page where they can review the extracted information and create activities.

### Example: Activities Redirect

This example shows how a controller might handle the redirect and pre-fill fields from the staged documents.

```ruby
# Example implementation for the redirect target
def new_from_staged
  @staged_documents = StagedDocument.find_signed(params[:staged_document_signed_ids])
  
  # Initialize activities from extracted DocAI results
  @activities = @staged_documents.map do |staged|
    result = DocAiResult.build(staged.extracted_fields)
    Activity.new(result.to_prefill_fields)
  end
  
  render :new_multiple
end
```

