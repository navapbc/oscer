# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:admin_user) { create(:user, :as_admin) }
  let(:non_admin_user) { create(:user) }
  let(:user) { admin_user }
  let(:record) { create(:certification_batch_upload, uploader: admin_user) }
  let(:resolved_scope) do
    described_class::Scope.new(user, CertificationBatchUpload.all).resolve
  end

  it_behaves_like "application policy"

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
end
