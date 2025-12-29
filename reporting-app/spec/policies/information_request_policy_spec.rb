# frozen_string_literal: true

require "rails_helper"

RSpec.describe InformationRequestPolicy, type: :policy do
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
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:application_form) do
    create(:activity_report_application_form, certification_case_id: certification_case.id)
  end
  let(:record) do
    create(
      :activity_report_information_request,
      application_form_id: application_form.id,
      application_form_type: application_form.class.name
    )
  end

  it_behaves_like "application policy"

  describe "when user is staff in the case's region" do
    let(:user) { staff_user }

    it { is_expected.to permit_actions(:show) }
    it { is_expected.to forbid_actions(:destroy) }
  end

  describe "when user is staff in a different region" do
    let(:user) { other_region_staff_user }

    it { is_expected.to forbid_actions(:show, :destroy) }
  end

  describe "when user is not staff" do
    let(:user) { non_staff_user }

    it { is_expected.to forbid_actions(:show, :destroy) }
  end

  describe "with exemption information request" do
    let(:exemption_form) do
      create(:exemption_application_form, certification_case_id: certification_case.id)
    end
    let(:record) do
      create(
        :exemption_information_request,
        application_form_id: exemption_form.id,
        application_form_type: exemption_form.class.name
      )
    end

    describe "when user is staff in the case's region" do
      let(:user) { staff_user }

      it { is_expected.to permit_actions(:show) }
    end

    describe "when user is staff in a different region" do
      let(:user) { other_region_staff_user }

      it { is_expected.to forbid_actions(:show) }
    end
  end
end
