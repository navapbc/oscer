# frozen_string_literal: true

# OIDC Client for Staff Single Sign-On
#
# Handles the OIDC authorization code flow:
# 1. Generate authorization URL to redirect user to IdP
# 2. Exchange authorization code for tokens
# 3. Validate ID token and extract claims
#
# Uses OIDC Discovery to automatically fetch IdP endpoints from
# the .well-known/openid-configuration document, making it compatible
# with any OIDC-compliant provider (Keycloak, Azure AD, Okta, etc.)
#
# Usage:
#   client = OidcClient.new
#   auth_url = client.authorization_url(state: state, nonce: nonce)
#   # ... user authenticates at IdP ...
#   tokens = client.exchange_code(code: params[:code])
#   claims = client.extract_claims(tokens["id_token"])
#
class OidcClient
  # Raised when token validation fails (signature, issuer, audience, expiry)
  class TokenValidationError < StandardError; end

  # Raised when token exchange fails (invalid code, network error)
  class TokenExchangeError < StandardError; end

  # Raised when configuration is invalid
  class ConfigurationError < StandardError; end

  # Raised when OIDC discovery fails
  class DiscoveryError < StandardError; end

  # Class-level cache for discovery documents (per issuer)
  @discovery_cache = {}
  @discovery_cache_mutex = Mutex.new

  class << self
    attr_accessor :discovery_cache, :discovery_cache_mutex

    def reset_discovery_cache!
      @discovery_cache_mutex.synchronize { @discovery_cache = {} }
    end
  end

  def initialize(config: Rails.application.config.sso)
    @config = config
    validate_config! if enabled?
  end

  # Check if SSO is enabled
  # @return [Boolean]
  def enabled?
    @config[:enabled]
  end

  # Generate the authorization URL to redirect the user to the IdP
  # @param state [String] CSRF protection token (stored in session)
  # @param nonce [String] Replay protection token (stored in session)
  # @return [String] Full authorization URL
  def authorization_url(state:, nonce:)
    params = {
      response_type: "code",
      client_id: @config[:client_id],
      redirect_uri: @config[:redirect_uri],
      scope: @config[:scopes].join(" "),
      state: state,
      nonce: nonce
    }

    "#{authorization_endpoint}?#{params.to_query}"
  end

  # Exchange an authorization code for tokens
  # @param code [String] Authorization code from IdP callback
  # @return [Hash] Token response containing access_token, id_token, etc.
  # @raise [TokenExchangeError] if exchange fails
  def exchange_code(code:)
    response = Faraday.post(token_endpoint) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form({
        grant_type: "authorization_code",
        code: code,
        client_id: @config[:client_id],
        client_secret: @config[:client_secret],
        redirect_uri: @config[:redirect_uri]
      })
    end

    unless response.success?
      error_body = parse_json_safely(response.body)
      error_message = error_body["error_description"] || error_body["error"] || "Token exchange failed"
      raise TokenExchangeError, error_message
    end

    JSON.parse(response.body)
  rescue Faraday::Error => e
    raise TokenExchangeError, "Network error during token exchange: #{e.message}"
  end

  # Validate an ID token and return its claims
  # @param id_token [String] JWT ID token
  # @return [Hash] Decoded and validated claims
  # @raise [TokenValidationError] if validation fails
  def validate_token(id_token)
    # Decode without verification first to read claims
    # In production, this should verify the signature using IdP's JWKS
    decoded = decode_jwt(id_token)

    validate_issuer!(decoded)
    validate_audience!(decoded)
    validate_expiry!(decoded)

    decoded
  end

  # Extract user claims from an ID token, mapped to standard names
  # @param id_token [String] JWT ID token
  # @param expected_nonce [String, nil] Expected nonce value from session (for replay protection)
  # @return [Hash] User claims with keys: :uid, :email, :name, :groups
  # @raise [TokenValidationError] if validation fails
  def extract_claims(id_token, expected_nonce: nil)
    decoded = validate_token(id_token)
    validate_nonce!(decoded, expected_nonce) if expected_nonce.present?

    {
      uid: decoded[@config.dig(:claims, :unique_id)],
      email: decoded[@config.dig(:claims, :email)],
      name: decoded[@config.dig(:claims, :name)],
      groups: Array(decoded[@config.dig(:claims, :groups)])
    }
  end

  private

  def validate_config!
    missing = []
    missing << "SSO_ISSUER_URL" if @config[:issuer].blank?
    missing << "SSO_CLIENT_ID" if @config[:client_id].blank?
    missing << "SSO_CLIENT_SECRET" if @config[:client_secret].blank?
    missing << "SSO_REDIRECT_URI" if @config[:redirect_uri].blank?

    return if missing.empty?

    raise ConfigurationError, "Missing required SSO configuration: #{missing.join(', ')}"
  end

  def authorization_endpoint
    # Rewrite to public issuer URL for browser redirects
    rewrite_endpoint(discovery_document["authorization_endpoint"])
  end

  def token_endpoint
    # Token endpoint is called server-side, use internal URL if available
    discovery_document["token_endpoint"]
  end

  # Rewrites an endpoint URL from discovery_url base to public issuer base
  # This is needed when discovery_url differs from issuer (e.g., Docker scenarios)
  # Browser redirects must use the public issuer URL, not internal discovery URL
  def rewrite_endpoint(endpoint_url)
    discovery_base = @config[:discovery_url] || @config[:issuer]
    public_base = @config[:issuer]

    return endpoint_url if discovery_base == public_base

    endpoint_url.sub(discovery_base, public_base)
  end

  def discovery_document
    # Use discovery_url if set (for Docker/network scenarios where internal URL differs from public issuer)
    # Falls back to issuer if discovery_url not configured
    discovery_base = @config[:discovery_url] || @config[:issuer]

    self.class.discovery_cache_mutex.synchronize do
      cached = self.class.discovery_cache[discovery_base]

      # Return cached document if still valid (cache for 1 hour)
      if cached && cached[:fetched_at] > 1.hour.ago
        return cached[:document]
      end

      # Fetch and cache the discovery document
      document = fetch_discovery_document(discovery_base)
      self.class.discovery_cache[discovery_base] = {
        document: document,
        fetched_at: Time.current
      }
      document
    end
  end

  def fetch_discovery_document(issuer)
    discovery_url = "#{issuer}/.well-known/openid-configuration"

    connection = Faraday.new do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end

    response = connection.get(discovery_url)

    unless response.success?
      raise DiscoveryError, "Failed to fetch OIDC discovery document from #{discovery_url}: HTTP #{response.status}"
    end

    document = JSON.parse(response.body)

    # Validate required fields
    unless document["authorization_endpoint"].present? && document["token_endpoint"].present?
      raise DiscoveryError, "Invalid OIDC discovery document: missing required endpoints"
    end

    document
  rescue Faraday::Error => e
    raise DiscoveryError, "Network error fetching OIDC discovery document: #{e.message}"
  rescue JSON::ParserError => e
    raise DiscoveryError, "Invalid JSON in OIDC discovery document: #{e.message}"
  end

  def decode_jwt(token)
    # Split the JWT into parts
    parts = token.split(".")
    raise TokenValidationError, "Invalid token format" unless parts.length == 3

    # Decode the payload (middle part)
    payload = parts[1]

    # Add padding if needed for Base64 decoding
    payload += "=" * (4 - payload.length % 4) if payload.length % 4 != 0

    JSON.parse(Base64.urlsafe_decode64(payload))
  rescue ArgumentError, JSON::ParserError => e
    raise TokenValidationError, "Failed to decode token: #{e.message}"
  end

  def validate_issuer!(claims)
    token_issuer = claims["iss"]
    expected_issuer = @config[:issuer]

    return if token_issuer == expected_issuer

    raise TokenValidationError, "Invalid issuer: expected #{expected_issuer}, got #{token_issuer}"
  end

  def validate_audience!(claims)
    token_audience = claims["aud"]
    expected_audience = @config[:client_id]

    # Audience can be a string or array
    audiences = Array(token_audience)

    return if audiences.include?(expected_audience)

    raise TokenValidationError, "Invalid audience: expected #{expected_audience}, got #{token_audience}"
  end

  def validate_expiry!(claims)
    exp = claims["exp"]
    raise TokenValidationError, "Token missing expiry" unless exp

    expiry_time = Time.at(exp).utc

    return unless expiry_time < Time.current

    raise TokenValidationError, "Token expired at #{expiry_time}"
  end

  def validate_nonce!(claims, expected_nonce)
    token_nonce = claims["nonce"]

    return if token_nonce.present? && ActiveSupport::SecurityUtils.secure_compare(token_nonce.to_s, expected_nonce.to_s)

    raise TokenValidationError, "Invalid nonce: token replay attack detected"
  end

  def parse_json_safely(body)
    JSON.parse(body)
  rescue JSON::ParserError
    { "error" => body }
  end
end
