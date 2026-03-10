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

  describe "#lookup?" do
    context "when user is logged in" do
      it "permits the action" do
        expect(policy).to permit_action(:lookup)
      end
    end
  end

  describe "Scope" do
    subject(:resolved_scope) { described_class::Scope.new(user, StagedDocument.all).resolve }

    let(:other_user) { create(:user) }
    let!(:user_staged_document) { create(:staged_document, user_id: user.id) }
    let!(:other_staged_document) { create(:staged_document, user_id: other_user.id) }


    it "includes staged documents belonging to the user" do
      expect(resolved_scope).to include(user_staged_document)
    end

    it "excludes staged documents belonging to other users" do
      expect(resolved_scope).not_to include(other_staged_document)
    end
  end
end
