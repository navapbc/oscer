# frozen_string_literal: true

require "ipaddr"

module Middleware
  # When the app runs behind Docker or an internal hop, Rack may see an internal
  # HTTP Host (e.g. container service name). Rails then builds absolute redirects
  # as request.protocol + request.host_with_port + path, which sends browsers to
  # the wrong host.
  #
  # If APP_HOST is set, treat it as the canonical public host for this deployment
  # and normalize Host / forwarded headers before the rest of the stack runs.
  #
  # When the browser already talks to a local dev host (localhost, 127.0.0.1,
  # host.docker.internal, loopback), we do not rewrite—even if APP_HOST is set for
  # OIDC callback URLs—so redirects stay on the same origin (e.g. Playwright E2E).
  #
  # In +test+, this middleware is a no-op so request specs (default host
  # +www.example.com+, +follow_redirect!+, flash/session) stay stable when CI sets
  # APP_HOST. Use {.apply_canonical_host!} in unit tests to assert rewrite behavior.
  #
  # See config/application.rb (middleware.unshift).
  class PublicRequestHost
    def initialize(app)
      @app = app
    end

    def call(env)
      self.class.apply_canonical_host!(env) unless self.class.skip_middleware?
      @app.call(env)
    end

    # @param env [Hash] Rack env (mutated when APP_HOST is set)
    # @return [void]
    def self.apply_canonical_host!(env)
      canonical = canonical_authority_from_env
      return if canonical.blank?

      current = env["HTTP_HOST"].to_s.strip
      return if current.casecmp?(canonical)
      return if local_browser_host?(current)

      env["HTTP_HOST"] = canonical
      env["HTTP_X_FORWARDED_HOST"] = canonical
      env["HTTP_X_FORWARDED_PROTO"] ||= forwarded_proto_from_env
    end

    def self.skip_middleware?
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?
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

    def self.local_browser_host?(http_host)
      hostname = http_host_hostname(http_host)
      return false if hostname.blank?

      hn = hostname.downcase
      return true if hn == "localhost" || hn == "host.docker.internal"

      begin
        IPAddr.new(hostname).loopback?
      rescue IPAddr::InvalidAddressError
        false
      end
    end

    def self.http_host_hostname(http_host)
      raw = http_host.to_s.strip
      return "" if raw.blank?

      if raw.start_with?("[")
        raw.split("]", 2).first.to_s.delete_prefix("[")
      else
        raw.split(":", 2).first
      end
    end
    private_class_method :http_host_hostname
  end
end
