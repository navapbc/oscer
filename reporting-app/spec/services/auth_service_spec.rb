# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  let(:mock_uid) { "mock_uid" }
  let(:mock_auth_adapter) { Auth::MockAdapter.new(uid_generator: -> { mock_uid }) }

  describe "#register" do
    it "creates a new user" do
      auth_service = described_class.new(mock_auth_adapter)

      auth_service.register("test@example.com", "password")

      user = User.find_by(uid: mock_uid)
      expect(user).to be_present
      expect(user.provider).to eq("mock")
      expect(user.email).to eq("test@example.com")
    end
  end

  describe "#change_email" do
    it "updates the user's email" do
      auth_service = described_class.new(mock_auth_adapter)
      User.create!(uid: mock_uid, email: "test@example.com", provider: "mock")

      auth_service.change_email(mock_uid, "new@example.com")

      user = User.find_by(uid: mock_uid)
      expect(user.email).to eq("new@example.com")
    end
  end

  describe "#initiate_auth" do
    it "creates a new user if one does not exist" do
      auth_service = described_class.new(mock_auth_adapter)

      response = auth_service.initiate_auth("test@example.com", "password")

      user = User.find_by(uid: mock_uid)
      expect(response[:user]).to eq(user)
    end

    it "updates the user's email if it has changed" do
      auth_service = described_class.new(mock_auth_adapter)
      User.create!(uid: mock_uid, email: "oldie@example.com", provider: "mock")

      response = auth_service.initiate_auth("new@example.com", "password")

      user = User.find_by(uid: mock_uid)
      expect(user.email).to eq("new@example.com")
    end
  end

  describe "#verify_account" do
    it "returns empty struct on success" do
      auth_service = described_class.new(mock_auth_adapter)

      expect(auth_service.verify_account("test@example.com", "123456")).to eq({})
    end
  end
end
