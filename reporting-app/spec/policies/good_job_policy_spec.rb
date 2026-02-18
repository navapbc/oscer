# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoodJobPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:admin_user) { create(:user, :as_admin) }
  let(:non_admin_user) { create(:user) }
  let(:record) { :good_job }

  it_behaves_like "application policy"

  describe "dashboard?" do
    context "when user is an admin" do
      let(:user) { admin_user }

      it { is_expected.to permit_action(:dashboard) }
    end

    context "when user is not an admin" do
      let(:user) { non_admin_user }

      it { is_expected.to forbid_action(:dashboard) }
    end
  end
end
