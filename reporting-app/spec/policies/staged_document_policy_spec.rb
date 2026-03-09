# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StagedDocumentPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:staged_document) { create(:staged_document, user_id: user&.id) }
  let(:policy) { described_class.new(user, staged_document) }

  describe "#create?" do
    context "when user is logged in" do
      it "permits the action" do
        expect(policy).to permit_action(:create)
      end
    end

    context "when user is not logged in" do
      it "raises a Pundit::NotAuthorizedError" do
        expect { described_class.new(nil, staged_document) }.to raise_error(Pundit::NotAuthorizedError, "must be logged in")
      end
    end
  end

  describe "#show?" do
    context "when user is the owner" do
      it "permits the action" do
        expect(policy).to permit_action(:show)
      end
    end

    context "when user is not the owner" do
      let(:other_user) { create(:user) }
      let(:policy) { described_class.new(other_user, staged_document) }

      it "forbids the action" do
        expect(policy).to forbid_action(:show)
      end
    end
  end
end
