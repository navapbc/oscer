# frozen_string_literal: true

require "jwt"
require "openssl"
require "securerandom"

class VaTokenManager
  class TokenError < StandardError; end

  def initialize(config: Rails.application.config.veteran_affairs)
    @config = config
    @token_cache = {} # { icn => { token: "...", expires_at: Time } }
  end

  def get_access_token(icn:)
    cached = @token_cache[icn]
    if cached && cached[:expires_at] > Time.current + 30
      return cached[:token]
    end

    fetch_new_token(icn: icn)
  end

  private

  def fetch_new_token(icn:)
    assertion = generate_client_assertion
    launch = Base64.strict_encode64({ patient: icn }.to_json)

    response = Faraday.post(@config[:token_host]) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form({
        grant_type: "client_credentials",
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion: assertion,
        scope: "disability_rating.read launch",
        launch: launch
      })
    end

    unless response.success?
      raise TokenError, "Failed to fetch VA token: #{response.status} #{response.body}"
    end

    data = JSON.parse(response.body)
    token = data["access_token"]
    expires_in = data["expires_in"].to_i

    @token_cache[icn] = {
      token: token,
      expires_at: Time.current + expires_in
    }

    token
  rescue Faraday::Error => e
    raise TokenError, "Network error fetching VA token: #{e.message}"
  end

  def generate_client_assertion
    private_key = OpenSSL::PKey::RSA.new(@config[:private_key])
    now = Time.current.to_i

    payload = {
      iss: @config[:client_id_ccg],
      sub: @config[:client_id_ccg],
      aud: @config[:audience],
      exp: now + 300 # 5 minutes
    }

    JWT.encode(payload, private_key, "RS256")
  end
end
