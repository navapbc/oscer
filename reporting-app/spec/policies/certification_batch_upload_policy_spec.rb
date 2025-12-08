# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:policy) { subject }

  let(:admin_user) { create(:user, role: "admin") }
  let(:non_admin_user) { create(:user, role: "staff") }
  let(:user) { admin_user }
  let(:record) { create(:certification_batch_upload, uploader: admin_user) }
  let(:resolved_scope) do
    described_class::Scope.new(user, CertificationBatchUpload.all).resolve
  end

  describe "when user is an admin" do
    it { is_expected.to permit_actions(:index, :new, :create, :edit, :update, :process_batch, :results, :show) }
    it { is_expected.to forbid_actions(:destroy) }

    it "includes all records in the resolved scope" do
      expect(resolved_scope).to include(record)
    end
  end

  describe "when user is not an admin" do
    let(:user) { non_admin_user }

    it { is_expected.to forbid_actions(:index, :new, :create, :edit, :update, :process_batch, :results, :show, :destroy) }

    it "includes no records in the resolved scope" do
      expect(resolved_scope).to be_empty
    end
  end

  describe "when user is nil" do
    let(:user) { nil }

    it "raises NotAuthorizedError" do
      expect { policy }.to raise_error(Pundit::NotAuthorizedError, "must be logged in")
    end
  end

  describe "inheritance from AdminPolicy" do
    it "inherits from AdminPolicy" do
      expect(policy.class < AdminPolicy).to be true
    end
  end
end
