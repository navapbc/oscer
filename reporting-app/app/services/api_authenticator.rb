# frozen_string_literal: true

class ApiAuthenticator
  class AuthenticationError < StandardError; end
  class MissingCredentials < AuthenticationError; end
  class InvalidSignature < AuthenticationError; end

  HEADER_FORMAT = /\AHMAC sig=(.+)\z/

  def authenticate!(request)
    auth_header = request.headers["Authorization"]
    raise MissingCredentials, "Missing Authorization header" if auth_header.blank?

    match = auth_header.match(HEADER_FORMAT)
    raise MissingCredentials, "Invalid Authorization header format" unless match

    provided_signature = match[1]
    expected_signature = sign(body: request.body.read)
    request.body.rewind # Ensure the body can be read again if needed

    unless ActiveSupport::SecurityUtils.secure_compare(provided_signature, expected_signature)
      raise InvalidSignature, "Signature verification failed"
    end

    true
  end

  def sign(body:)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha256", secret_key, body)
    )
  end

  private

  def secret_key
    ENV.fetch("API_SECRET_KEY")
  end
end
