# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:admin_user) { create(:user, role: "admin") }
  let(:non_admin_user) { create(:user, role: "staff") }
  let(:record) { create(:certification_batch_upload) }

  describe "when user is an admin" do
    let(:user) { admin_user }

    it "allows all actions" do
      expect(subject.index?).to be true
      expect(subject.show?).to be true
      expect(subject.create?).to be true
      expect(subject.new?).to be true
      expect(subject.update?).to be true
      expect(subject.edit?).to be true
      expect(subject.destroy?).to be false
    end
  end

  describe "when user is not an admin" do
    let(:user) { non_admin_user }

    it "denies all actions" do
      expect(subject.index?).to be false
      expect(subject.show?).to be false
      expect(subject.create?).to be false
      expect(subject.new?).to be false
      expect(subject.edit?).to be false
      expect(subject.update?).to be false
      expect(subject.destroy?).to be false
    end
  end

  describe "when user is nil" do
    let(:user) { nil }

    it "raises NotAuthorizedError" do
      expect { subject }.to raise_error(Pundit::NotAuthorizedError, "must be logged in")
    end
  end
end
