# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::PublicRequestHost do
  def with_env(overrides, &block)
    old = {}
    overrides.each do |key, value|
      old[key] = ENV[key]
      ENV[key] = value
    end
    block.call
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  subject(:middleware) { described_class.new(inner_app) }

  let(:inner_app) do
    lambda do |env|
      req = ActionDispatch::Request.new(env)
      [ 200, { "Content-Type" => "text/plain" }, [ "#{req.scheme}://#{req.host_with_port}" ] ]
    end
  end

  describe "#call" do
    it "does not rewrite when APP_HOST is unset" do
      with_env("APP_HOST" => nil) do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        _status, _headers, body = middleware.call(env)
        expect(body.join).to eq("http://web:3000")
      end
    end

    it "does not rewrite in test even when APP_HOST is set (request specs stay host-stable)" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        _status, _headers, body = middleware.call(env)
        expect(body.join).to eq("http://web:3000")
      end
    end
  end

  describe ".apply_canonical_host!" do
    def response_url_after_apply(env)
      described_class.apply_canonical_host!(env)
      req = ActionDispatch::Request.new(env)
      "#{req.scheme}://#{req.host_with_port}"
    end

    it "does nothing when APP_HOST is unset" do
      with_env("APP_HOST" => nil) do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)
        expect(env["HTTP_HOST"]).to eq("web:3000")
      end
    end

    it "replaces internal Host with APP_HOST for Rack request URL helpers" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        expect(response_url_after_apply(env)).to eq("https://app.example.com")
      end
    end

    it "adds non-standard HTTPS port to Host" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "3000", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        expect(response_url_after_apply(env)).to eq("https://localhost:3000")
      end
    end

    it "sets X-Forwarded-Proto to http when DISABLE_HTTPS is true" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "80", "DISABLE_HTTPS" => "true") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        expect(response_url_after_apply(env)).to eq("http://localhost")
      end
    end

    it "does not replace X-Forwarded-Proto when already set" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for(
          "/",
          "HTTP_HOST" => "web:3000",
          "HTTP_X_FORWARDED_PROTO" => "http"
        )
        expect(response_url_after_apply(env)).to eq("http://app.example.com")
      end
    end
  end
end
