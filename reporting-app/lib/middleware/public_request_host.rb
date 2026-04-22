# frozen_string_literal: true

module Middleware
  # When the app runs behind Docker or an internal hop, Rack may see an internal
  # HTTP Host (e.g. container service name). Rails then builds absolute redirects
  # as request.protocol + request.host_with_port + path, which sends browsers to
  # the wrong host.
  #
  # If APP_HOST is set, treat it as the canonical public host for this deployment
  # and normalize Host / forwarded headers before the rest of the stack runs.
  #
  # Disabled when:
  # - +RAILS_ENV=test+ (request specs / stable default host)
  # - +SKIP_PUBLIC_REQUEST_HOST+ is the string +true+ (e.g. Playwright E2E against a host
  #   that is not APP_HOST while APP_HOST stays set for OIDC—set on the Rails process)
  #
  # Use {.apply_canonical_host!} in unit tests to assert rewrite behavior.
  #
  # See config/application.rb (middleware.unshift).
  class PublicRequestHost
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if self.class.skip_middleware?

      self.class.apply_canonical_host!(env)
      @app.call(env)
    end

    # @param env [Hash] Rack env (mutated when APP_HOST is set)
    # @return [void]
    def self.apply_canonical_host!(env)
      canonical = canonical_authority_from_env
      return if canonical.blank?

      env["HTTP_HOST"] = canonical
      env["HTTP_X_FORWARDED_HOST"] = canonical
      env["HTTP_X_FORWARDED_PROTO"] ||= forwarded_proto_from_env
    end

    def self.skip_middleware?
      return true if skip_public_request_host_env?
      return true if defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?

      false
    end

    def self.skip_public_request_host_env?
      ENV["SKIP_PUBLIC_REQUEST_HOST"] == "true"
    end

    def self.canonical_authority_from_env
      app_host = ENV["APP_HOST"]&.strip
      return nil if app_host.blank?

      port = ENV.fetch("APP_PORT", "443").to_s.strip
      https_disabled = ENV["DISABLE_HTTPS"] == "true"
      standard_port = https_disabled ? "80" : "443"

      if port.present? && port != standard_port
        "#{app_host}:#{port}"
      else
        app_host
      end
    end

    def self.forwarded_proto_from_env
      ENV["DISABLE_HTTPS"] == "true" ? "http" : "https"
    end
  end
end
