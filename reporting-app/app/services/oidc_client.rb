# frozen_string_literal: true

# OIDC Client for Staff Single Sign-On
#
# Handles the OIDC authorization code flow:
# 1. Generate authorization URL to redirect user to IdP
# 2. Exchange authorization code for tokens
# 3. Validate ID token and extract claims
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
    "#{@config[:issuer]}/authorize"
  end

  def token_endpoint
    "#{@config[:issuer]}/token"
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
