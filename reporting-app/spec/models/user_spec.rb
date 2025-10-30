# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe "access_token" do
    let(:user) { build(:user) }

    it "is an attr_accessor so we can store the token in the session" do
      expect(user).to respond_to(:access_token)
      expect(user).to respond_to(:access_token=)
    end
  end

  describe "access_token_expires_within_minutes?" do
    let(:user) { build(:user) }
    let(:access_token) {
      JWT.encode({ exp: 5.minutes.from_now.to_i }, nil)
    }

    it "returns true if the access token expires within the designated minutes" do
      expect(user.access_token_expires_within_minutes?(access_token, 5)).to be(true)
    end

    it "returns false if the access token is not expiring within the designated minutes" do
      expect(user.access_token_expires_within_minutes?(access_token, 1)).to be(false)
    end
  end
end
