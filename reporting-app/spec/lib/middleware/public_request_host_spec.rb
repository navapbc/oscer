# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::PublicRequestHost do
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

    it "does not rewrite when SKIP_PUBLIC_REQUEST_HOST is set outside test" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      with_env(
        "APP_HOST" => "app.example.com",
        "APP_PORT" => "443",
        "DISABLE_HTTPS" => "false",
        "SKIP_PUBLIC_REQUEST_HOST" => "true"
      ) do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "localhost:3000")
        _status, _headers, body = middleware.call(env)
        expect(body.join).to eq("http://localhost:3000")
      end
    end

    it "rewrites internal Host in development when SKIP_PUBLIC_REQUEST_HOST is unset" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      with_env(
        "APP_HOST" => "app.example.com",
        "APP_PORT" => "443",
        "DISABLE_HTTPS" => "false",
        "SKIP_PUBLIC_REQUEST_HOST" => nil
      ) do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        _status, _headers, body = middleware.call(env)
        expect(body.join).to eq("https://app.example.com")
      end
    end
  end

  describe ".apply_canonical_host!" do
    it "does nothing when APP_HOST is unset" do
      with_env("APP_HOST" => nil) do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)
        expect(env["HTTP_HOST"]).to eq("web:3000")
        expect(env["HTTP_X_FORWARDED_HOST"]).to be_nil
        expect(env["HTTP_X_FORWARDED_PROTO"]).to be_nil
      end
    end

    it "sets HTTP_HOST, HTTP_X_FORWARDED_HOST, and HTTP_X_FORWARDED_PROTO from env defaults (HTTPS)" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("app.example.com")
        expect(env["HTTP_X_FORWARDED_HOST"]).to eq("app.example.com")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("https")

        req = ActionDispatch::Request.new(env)
        expect("#{req.scheme}://#{req.host_with_port}").to eq("https://app.example.com")
      end
    end

    it "defaults APP_PORT to 443 when unset so Host omits the standard HTTPS port" do
      with_env("APP_HOST" => "secure.example.com", "APP_PORT" => nil, "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("secure.example.com")
        expect(env["HTTP_HOST"]).not_to include(":")
        expect(env["HTTP_X_FORWARDED_HOST"]).to eq("secure.example.com")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("https")
      end
    end

    it "omits port suffix from Host when APP_PORT is blank (same shape as standard HTTPS 443)" do
      with_env("APP_HOST" => "secure.example.com", "APP_PORT" => "", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("secure.example.com")
        expect(env["HTTP_HOST"]).not_to include(":")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("https")
      end
    end

    it "sets HTTP_X_FORWARDED_PROTO to http when DISABLE_HTTPS is true" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "80", "DISABLE_HTTPS" => "true") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("localhost")
        expect(env["HTTP_X_FORWARDED_HOST"]).to eq("localhost")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("http")
      end
    end

    it "adds non-standard HTTPS port to Host and forwarded headers" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "3000", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "web:3000")
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("localhost:3000")
        expect(env["HTTP_X_FORWARDED_HOST"]).to eq("localhost:3000")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("https")

        req = ActionDispatch::Request.new(env)
        expect("#{req.scheme}://#{req.host_with_port}").to eq("https://localhost:3000")
      end
    end

    it "does not replace X-Forwarded-Proto when already set" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        env = Rack::MockRequest.env_for(
          "/",
          "HTTP_HOST" => "web:3000",
          "HTTP_X_FORWARDED_PROTO" => "http"
        )
        described_class.apply_canonical_host!(env)

        expect(env["HTTP_HOST"]).to eq("app.example.com")
        expect(env["HTTP_X_FORWARDED_HOST"]).to eq("app.example.com")
        expect(env["HTTP_X_FORWARDED_PROTO"]).to eq("http")
      end
    end
  end
end
