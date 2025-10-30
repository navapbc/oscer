# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::CognitoAdapter::Config do
  describe "#from_env" do
    it "handles complete env vars" do
      stub_const('ENV', { 'COGNITO_CLIENT_ID' => 'foo', 'COGNITO_CLIENT_SECRET' => "my-secret", "COGNITO_USER_POOL_ID" => "baz" })

      config = described_class.from_env()

      expect(config).to eq(described_class.new(client_id: "foo", client_secret: "my-secret", user_pool_id: "baz"))
    end

    it "handles partial env vars" do
      stub_const('ENV', { 'COGNITO_CLIENT_ID' => 'foo', 'COGNITO_CLIENT_SECRET' => "my-secret" })

      config = described_class.from_env()

      expect(config).to eq(described_class.new(client_id: "foo", client_secret: "my-secret", user_pool_id: nil))
    end

    it "handles empty env vars" do
      stub_const('ENV', {})

      config = described_class.from_env()

      expect(config).to eq(described_class.new(client_id: nil, client_secret: nil, user_pool_id: nil))
    end
  end
end
