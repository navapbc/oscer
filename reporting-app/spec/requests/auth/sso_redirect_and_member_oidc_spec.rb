# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OIDC redirect URI and member_oidc config (Story 1)", type: :request do
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

  describe "build_oidc_redirect_uri" do
    it "returns HTTPS URI with default host and port when DISABLE_HTTPS is not set" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        uri = build_oidc_redirect_uri("/auth/sso/callback")
        expect(uri).to eq("https://app.example.com/auth/sso/callback")
      end
    end

    it "includes port suffix when APP_PORT is non-standard for HTTPS" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "3000", "DISABLE_HTTPS" => "false") do
        uri = build_oidc_redirect_uri("/auth/sso/callback")
        expect(uri).to eq("https://localhost:3000/auth/sso/callback")
      end
    end

    it "uses HTTP and port 80 when DISABLE_HTTPS is true" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "80", "DISABLE_HTTPS" => "true") do
        uri = build_oidc_redirect_uri("/auth/sso/callback")
        expect(uri).to eq("http://localhost/auth/sso/callback")
      end
    end

    it "builds member_oidc callback path when given that path" do
      with_env("APP_HOST" => "app.example.com", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        uri = build_oidc_redirect_uri("/auth/member_oidc/callback")
        expect(uri).to eq("https://app.example.com/auth/member_oidc/callback")
      end
    end

    it "normalizes path to start with slash" do
      with_env("APP_HOST" => "localhost", "APP_PORT" => "443", "DISABLE_HTTPS" => "false") do
        uri = build_oidc_redirect_uri("auth/sso/callback")
        expect(uri).to eq("https://localhost/auth/sso/callback")
      end
    end
  end

  describe "Rails.application.config.member_oidc" do
    it "has enabled and claims keys" do
      config = Rails.application.config.member_oidc
      expect(config).to include(:enabled, :claims)
    end

    it "has enabled false by default (MEMBER_OIDC_ENABLED not set)" do
      config = Rails.application.config.member_oidc
      expect(config[:enabled]).to be(false)
    end

    it "has claims with email, name, and unique_id keys" do
      config = Rails.application.config.member_oidc
      expect(config[:claims]).to include(:email, :name, :unique_id)
    end

    it "uses default claim key names when env vars are not set" do
      config = Rails.application.config.member_oidc
      expect(config[:claims][:email]).to eq("email")
      expect(config[:claims][:name]).to eq("name")
      expect(config[:claims][:unique_id]).to eq("sub")
    end
  end
end
