# frozen_string_literal: true

# Veteran Affairs (VA) API Configuration
#
# This initializer sets up the configuration for the VA Eligibility API integration.
# It currently supports Option 1: Client Credentials Grant (server-to-server) only.
#
# Required environment variables:
#   VA_CLIENT_ID_CCG - OAuth client ID for Client Credentials
#   VA_PRIVATE_KEY   - Private key for JWT signing (RS256)
#
# Optional environment variables:
#   VA_API_HOST      - VA API base endpoint (default: https://sandbox-api.va.gov)
#   VA_TOKEN_AUDIENCE - OAuth token audience for Client Credentials (default: sandbox Okta endpoint)
#   VA_TOKEN_HOST    - OAuth token endpoint for Client Credentials (default: sandbox VA endpoint)

Rails.application.config.veteran_affairs = {
  # API Endpoints
  api_host: ENV.fetch("VA_API_HOST", "https://sandbox-api.va.gov"),
  audience: ENV.fetch("VA_TOKEN_AUDIENCE", "https://deptva-eval.okta.com/oauth2/ausi3u00gw66b9Ojk2p7/v1/token"),
  token_host: ENV.fetch("VA_TOKEN_HOST", "https://sandbox-api.va.gov/oauth2/veteran-verification/system/v1/token"),

  # Client Credentials Grant (Server-to-Server)
  client_id_ccg: ENV.fetch("VA_CLIENT_ID_CCG", nil),
  private_key: ENV.fetch("VA_PRIVATE_KEY", nil)
}.freeze
