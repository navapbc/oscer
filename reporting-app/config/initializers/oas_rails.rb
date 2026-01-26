# frozen_string_literal: true

OasRails.configure do |config|
  # Basic Information about the API
  config.info.title = "Community Engagement Medicaid"
  config.info.version = "1.0.0"
  config.info.summary = "System for tracking and certifying community engagement requirements for Medicaid"
  config.info.description = <<~HEREDOC
    # Community Engagement Medicaid API

    ## Authentication

    All API endpoints (except `/api/healthcheck`) require HMAC-SHA256 authentication.

    ### Request Format
    ```
    Authorization: HMAC sig={base64_signature}
    ```

    ### Generating the Signature

    1. Take the raw JSON request body
    2. Compute HMAC-SHA256 using the shared secret key
    3. Base64-encode (strict) the result

    **Ruby Example:**
    ```ruby
    body = { member_id: "123" }.to_json
    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha256", secret_key, body)
    )
    # Header: Authorization: HMAC sig=\#{signature}
    ```

    **curl Example (POST):**
    ```bash
    BODY='{"member_id":"123"}'
    SIG=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$API_SECRET_KEY" -binary | base64)
    curl -X POST https://api.example.com/api/certifications \\
      -H "Content-Type: application/json" \\
      -H "Authorization: HMAC sig=$SIG" \\
      -d "$BODY"
    ```

    **curl Example (GET):**
    ```bash
    # For GET requests (no body), the signature is computed from an empty string
    SIG=$(echo -n "" | openssl dgst -sha256 -hmac "$API_SECRET_KEY" -binary | base64)
    curl -X GET https://api.example.com/api/certifications/{id} \\
      -H "Authorization: HMAC sig=$SIG"
    ```
  HEREDOC
  config.info.contact.name = "Nava PBC"
  config.info.contact.email = "medicaid@navapbc.com"
  config.info.contact.url = "https://github.com/navapbc/oscer"

  # the license of the project is not necessarily the license of the API, but as
  # a starting place
  config.info.license.name = "Apache-2.0"
  config.info.license.url = "https://opensource.org/license/apache-2-0"

  # Servers Information. For more details follow: https://spec.openapis.org/oas/latest.html#server-object
  config.servers = [
    { url: "", description: "Current server" },
    { url: "http://medicaid.navateam.com", description: "Dev" }
  ]

  # Shared schemas
  config.source_oas_path = "lib/assets/oas.json"

  # Tag Information. For more details follow: https://spec.openapis.org/oas/latest.html#tag-object
  # config.tags = [ { name: "Users", description: "Manage the `amazing` Users table." } ]

  # Optional Settings (Uncomment to use)

  # Extract default tags of operations from namespace or controller. Can be set to :namespace or :controller
  # config.default_tags_from = :namespace

  # Automatically detect request bodies for create/update methods
  # Default: true
  # config.autodiscover_request_body = false

  # Automatically detect responses from controller renders
  # Default: true
  # config.autodiscover_responses = false

  # API path configuration if your API is under a different namespace
  config.api_path = "/api/"

  # Apply your custom layout. Should be the name of your layout file
  # Example: "application" if file named application.html.erb
  # Default: false
  # config.layout = "application"

  # Override general rapidoc settings
  # config.rapidoc_configuration
  # default: {}

  # Add a logo to rapidoc
  # config.rapidoc_logo_url
  # default: nil

  # Override specific rapidoc theme settings
  # config.rapidoc_theme_configuration
  # default: {}

  # Excluding custom controllers or controllers#action
  # Example: ["projects", "users#new"]
  # config.ignored_actions = []

  # #######################
  # Authentication Settings
  # #######################

  # Whether to authenticate all routes by default
  # Default is true; set to false if you don't want all routes to include security schemas by default
  config.authenticate_all_routes_by_default = true

  # Default security schema used for authentication
  # Choose a predefined security schema
  # [:api_key_cookie, :api_key_header, :api_key_query, :basic, :bearer, :bearer_jwt, :mutual_tls]
  # config.security_schema = :bearer

  # Custom security schemas
  # You can uncomment and modify to use custom security schemas
  # Please follow the documentation: https://spec.openapis.org/oas/latest.html#security-scheme-object
  #
  config.security_schemas = {
    hmac: {
      type: "apiKey",
      name: "Authorization",
      in: "header",
      description: "HMAC signature in format: HMAC sig={base64_signature}"
    }
  }

  # ###########################
  # Default Responses (Errors)
  # ###########################

  # The default responses errors are set only if the action allow it.
  # Example, if you add forbidden then it will be added only if the endpoint requires authentication.
  # Example: not_found will be setted to the endpoint only if the operation is a show/update/destroy action.
  config.set_default_responses = false
  # config.possible_default_responses = [:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_content]
  # config.response_body_of_default = "Hash{ errors: Array<String> }"
  # config.response_body_of_unprocessable_entity= "Hash{ errors: Array<String> }"
end
