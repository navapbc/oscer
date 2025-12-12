# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:region) { "Southeast" }
  let(:other_region) { "Northeast" }

  let(:staff_user) { create(:user, role: "caseworker", region: region) }
  let(:other_region_staff_user) { create(:user, role: "caseworker", region: other_region) }
  let(:non_staff_user) { create(:user, role: nil, region: nil) }

  let(:certification) do
    create(
      :certification,
      certification_requirements: build(:certification_certification_requirements, region: region)
    )
  end
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:record) { create(:review_activity_report_task, case: certification_case) }

  let(:resolved_scope) do
    described_class::Scope.new(user, Strata::Task.all).resolve
  end

  it_behaves_like "application policy"

  describe "when user is staff in the task's region" do
    let(:user) { staff_user }

    it { is_expected.to permit_actions(:index, :show, :update, :pick_up_next_task, :assign, :request_information, :create_information_request) }
    it { is_expected.to forbid_actions(:destroy) }

    it "includes tasks from the user's region in the resolved scope" do
      expect(resolved_scope).to include(record)
    end

    context "with multiple regions" do
      let(:other_certification) do
        create(
          :certification,
          certification_requirements: build(:certification_certification_requirements, region: other_region)
        )
      end
      let(:other_certification_case) { create(:certification_case, certification_id: other_certification.id) }
      let(:other_region_task) { create(:review_activity_report_task, case: other_certification_case) }

      before do
        record # ensure record is created
        other_region_task # ensure other_region_task is created
      end

      it "includes only tasks from the user's region in the resolved scope" do
        expect(resolved_scope).to include(record)
        expect(resolved_scope).not_to include(other_region_task)
      end
    end
  end

  describe "when user is staff in a different region" do
    let(:user) { other_region_staff_user }

    it { is_expected.to permit_actions(:index, :pick_up_next_task) }
    it { is_expected.to forbid_actions(:show, :update, :assign, :request_information, :create_information_request, :destroy) }

    it "does not include tasks from other regions in the resolved scope" do
      expect(resolved_scope).not_to include(record)
    end
  end

  describe "when user is not staff" do
    let(:user) { non_staff_user }

    it { is_expected.to forbid_actions(:index, :show, :update, :pick_up_next_task, :assign, :request_information, :create_information_request, :destroy) }

    it "includes no records in the resolved scope" do
      expect(resolved_scope).to be_empty
    end
  end
end
