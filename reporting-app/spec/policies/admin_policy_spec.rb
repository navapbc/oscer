# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:admin_user) { create(:user, role: "admin") }
  let(:non_admin_user) { create(:user, role: "staff") }
  let(:record) { create(:certification_batch_upload) }
  let(:resolved_scope) do
    described_class::Scope.new(user, CertificationBatchUpload.all).resolve
  end

  it_behaves_like "policy that requires a logged in user"

  describe "when user is an admin" do
    let(:user) { admin_user }

    it { is_expected.to permit_actions(:index, :show, :create, :new, :update, :edit) }
    it { is_expected.to forbid_actions(:destroy) }

    it "includes all records in the resolved scope" do
      expect(resolved_scope).to include(record)
    end
  end

  describe "when user is not an admin" do
    let(:user) { non_admin_user }

    it { is_expected.to forbid_actions(:index, :show, :create, :new, :update, :edit, :destroy) }

    it "includes no records in the resolved scope" do
      expect(resolved_scope).to be_empty
    end
  end
end
