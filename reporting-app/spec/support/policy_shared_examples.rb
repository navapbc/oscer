# frozen_string_literal: true

RSpec.shared_examples "policy that requires a logged in user" do
  describe "when user is nil" do
    let(:user) { nil }
    let(:policy) { described_class.new(user, record) }

    it "raises NotAuthorizedError" do
      expect { policy }.to raise_error(Pundit::NotAuthorizedError, "must be logged in")
    end
  end
end
