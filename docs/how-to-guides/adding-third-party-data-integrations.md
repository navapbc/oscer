# Adding Third Party Data Integrations

This guide explains how to add new external data integrations to the project using our standardized pattern.

## Architecture Overview

Data integrations are split into two layers:
1. **Adapters**: Handle low-level HTTP communication, authentication, and error handling.
2. **Services**: Handle high-level business logic, token management, and data orchestration.

We use base classes in `app/adapters/data_integration/` and `app/services/data_integration/` to ensure consistency.

## Step 1: Create an Adapter

Your adapter should inherit from `DataIntegration::BaseAdapter` and be placed in `app/adapters/`.

```ruby
# app/adapters/example_adapter.rb
class ExampleAdapter < DataIntegration::BaseAdapter
  def get_data(id:)
    with_error_handling do
      @connection.get("v1/data/#{id}")
    end
  end

  private

  def default_connection
    Faraday.new(url: Rails.application.config.example_api[:host]) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def adapter_name
    "Example API"
  end

  # Optional: Override if the API doesn't use standard ratelimit-remaining headers
  # def handle_rate_limit_headers(response)
  # end
end
```

`BaseAdapter` provides:
- `with_error_handling`: Automatically handles common HTTP status codes (401, 429, 5xx) and raises specific errors.
- `before_request`: Class method to register hooks that run before the request is made.
- `after_request`: Class method to register hooks that run after the request is made (receives the response object).

### Using Hooks

You can use hooks to handle cross-cutting concerns like logging or custom rate limit checking.

```ruby
class ExampleAdapter < DataIntegration::BaseAdapter
  before_request :log_request_start
  after_request :check_custom_headers

  private

  def log_request_start
    Rails.logger.info("Starting request to #{adapter_name}")
  end

  def check_custom_headers(response)
    # Custom logic using the response object
  end
end
```

## Step 2: Create a Service

Your service should inherit from `DataIntegration::BaseService` and be placed in `app/services/`.

```ruby
# app/services/example_data_service.rb
class ExampleDataService < DataIntegration::BaseService
  def initialize(adapter: ExampleAdapter.new)
    super(adapter: adapter)
  end

  def fetch_processed_data(id:)
    data = @adapter.get_data(id: id)
    # Process data...
  rescue ExampleAdapter::ApiError => e
    handle_integration_error(e)
  end

  private

  def service_name
    "Example API"
  end
end
```

`BaseService` provides:
- `handle_integration_error`: Standardizes logging for integration failures.

## Step 3: Add Tests

Always include RSpec tests for both your adapter and service.

- **Adapter tests**: Mock external API responses using WebMock or similar.
- **Service tests**: Mock the adapter to test business logic in isolation.

## Step 4: Update Configuration

Add any necessary API hosts or credentials to `config/application.rb` or credentials files.

```ruby
# config/application.rb
config.example_api = {
  host: ENV.fetch("EXAMPLE_API_HOST", "https://api.example.com")
}
```
