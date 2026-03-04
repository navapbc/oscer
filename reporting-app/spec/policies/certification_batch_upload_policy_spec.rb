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

    it "includes both staff and API records in scope" do
      staff_upload = create(:certification_batch_upload, uploader: admin_user)
      api_upload = create(:certification_batch_upload, :api_sourced)

      expect(resolved_scope).to include(staff_upload)
      expect(resolved_scope).to include(api_upload)
    end
  end

  describe "when user is not an admin" do
    let(:user) { non_admin_user }

    it { is_expected.to forbid_actions(:index, :new, :create, :edit, :update, :process_batch, :results, :show, :destroy) }

    it "includes no records in the resolved scope" do
      expect(resolved_scope).to be_empty
    end
  end

  describe "when user is an Api::Client" do
    let(:user) { Api::Client.new }

    it { is_expected.to permit_actions(:create, :show) }
    it { is_expected.to forbid_actions(:index, :new, :edit, :update, :destroy, :results, :download_errors) }

    it "includes only API-sourced records in scope" do
      staff_upload = create(:certification_batch_upload, uploader: admin_user)
      api_upload = create(:certification_batch_upload, :api_sourced)

      expect(resolved_scope).to include(api_upload)
      expect(resolved_scope).not_to include(staff_upload)
    end
  end
end
