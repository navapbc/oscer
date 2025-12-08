# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StaffPolicy, type: :policy do
  subject { described_class.new(current_user, :staff) }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:caseworker_user) { create(:user, :as_caseworker) }
  let(:regular_user) { create(:user, role: nil) }
  let(:other_role_user) { create(:user, role: 'member') }

  context "when user has no role" do
    let(:current_user) { regular_user }

    it { is_expected.to forbid_all_actions }
  end

  context "when user has admin role" do
    let(:current_user) { admin_user }

    it { is_expected.to permit_all_actions }
  end

  context "when user has caseworker role" do
    let(:current_user) { caseworker_user }

    it { is_expected.to permit_all_actions }
  end

  context "when user has other role" do
    let(:current_user) { other_role_user }

    it { is_expected.to forbid_all_actions }
  end

  describe "Scope" do
    let(:user) { create(:user) }
    let(:second_user) { create(:user) }

    before do
      user
      second_user
    end

    context "when user is staff (admin)" do
      let(:current_user) { admin_user }
      let(:resolved_scope) do
        described_class::Scope.new(current_user, User.all).resolve
      end

      it 'includes all records in the resolved scope' do
        expect(resolved_scope).to include(user, second_user, admin_user)
      end
    end

    context "when user is staff (caseworker)" do
      let(:current_user) { caseworker_user }
      let(:resolved_scope) do
        described_class::Scope.new(current_user, User.all).resolve
      end

      it 'includes all records in the resolved scope' do
        expect(resolved_scope).to include(user, second_user, caseworker_user)
      end
    end
  end
end
