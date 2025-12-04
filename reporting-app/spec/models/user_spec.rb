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

  describe "validations" do
    describe "role validation" do
      it "accepts valid role values" do
        expect(build(:user, role: "caseworker")).to be_valid
        expect(build(:user, role: "supervisor")).to be_valid
      end

      it "rejects invalid role values" do
        user = build(:user, role: "invalid_role")
        expect(user).not_to be_valid
        expect(user.errors[:role]).to be_present
      end
    end

    describe "program validation" do
      it "accepts valid program values" do
        expect(build(:user, program: "Medicaid")).to be_valid
        expect(build(:user, program: "SNAP")).to be_valid
      end

      it "rejects invalid program values" do
        user = build(:user, program: "Invalid Program")
        expect(user).not_to be_valid
        expect(user.errors[:program]).to be_present
      end
    end

    describe "region validation" do
      it "accepts valid region values" do
        expect(build(:user, region: "Northwest")).to be_valid
        expect(build(:user, region: "Northeast")).to be_valid
        expect(build(:user, region: "Southwest")).to be_valid
        expect(build(:user, region: "Southeast")).to be_valid
      end

      it "rejects invalid region values" do
        user = build(:user, region: "Central")
        expect(user).not_to be_valid
        expect(user.errors[:region]).to be_present
      end
    end
  end
end
