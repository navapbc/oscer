# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationCasePolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:region) { "Southeast" }
  let(:other_region) { "Northeast" }

  let(:staff_user) { create(:user, :as_caseworker, region: region) }
  let(:other_region_staff_user) { create(:user, :as_caseworker, region: other_region) }
  let(:non_staff_user) { create(:user, role: nil, region: nil) }

  let(:certification) do
    create(
      :certification,
      certification_requirements: build(:certification_certification_requirements, region: region)
    )
  end
  let(:record) { create(:certification_case, certification_id: certification.id) }

  let(:resolved_scope) do
    described_class::Scope.new(user, CertificationCase.all).resolve
  end

  it_behaves_like "application policy"

  describe "when user is staff in the case's region" do
    let(:user) { staff_user }

    it { is_expected.to permit_actions(:index, :show) }
    it { is_expected.to forbid_actions(:destroy) }

    it "includes cases from the user's region in the resolved scope" do
      expect(resolved_scope).to include(record)
    end

    context "with multiple regions" do
      let(:other_certification) do
        create(
          :certification,
          certification_requirements: build(:certification_certification_requirements, region: other_region)
        )
      end
      let(:other_region_case) { create(:certification_case, certification_id: other_certification.id) }

      before do
        record # ensure record is created
        other_region_case # ensure other_region_case is created
      end

      it "includes only cases from the user's region in the resolved scope" do
        expect(resolved_scope).to include(record)
        expect(resolved_scope).not_to include(other_region_case)
      end
    end
  end

  describe "when user is staff in a different region" do
    let(:user) { other_region_staff_user }

    it { is_expected.to forbid_actions(:index, :show, :destroy) }

    it "does not include cases from other regions in the resolved scope" do
      expect(resolved_scope).not_to include(record)
    end
  end

  describe "when user is not staff" do
    let(:user) { non_staff_user }

    it { is_expected.to forbid_actions(:index, :show, :destroy) }

    it "includes no records in the resolved scope" do
      expect(resolved_scope).to be_empty
    end
  end
end
