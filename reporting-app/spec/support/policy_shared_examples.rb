# frozen_string_literal: true

RSpec.shared_examples "application policy" do
  describe "when user is nil" do
    let(:user) { nil }
    let(:policy) { described_class.new(user, record) }

    it "raises NotAuthorizedError" do
      expect { policy }.to raise_error(Pundit::NotAuthorizedError, "must be logged in")
    end
  end

  describe "it inherits from ApplicationPolicy" do
    let(:user) { create(:user) }
    let(:policy) { described_class.new(user, record) }

    it "inherits from ApplicationPolicy" do
      expect(policy.class < ApplicationPolicy).to be true
    end
  end
end
