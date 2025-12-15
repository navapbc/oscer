# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::CreationService, type: :service do
  let(:member_id) { "member-123" }
  let(:case_number) { "case-456" }
  let(:certification_date) { Date.new(2025, 12, 25) }

  let(:base_params) do
    {
      member_id: member_id,
      case_number: case_number,
      member_data: member_data.as_json,
      certification_requirements: build(:certification_certification_requirement_params,
        :with_direct_params,
        certification_date: certification_date
      ).as_json
    }
  end

  let(:create_request) { Api::Certifications::CreateRequest.new(**base_params) }
  let(:service) { described_class.new(create_request) }

  describe "#call" do
    context "with hourly activities" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "employer" => "Acme Corp",
              "verification_status" => "verified"
            }
          ]
        )
      end

      it "creates a certification successfully" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)

        expect(service.certification).to be_persisted
        expect(service.certification.member_id).to eq(member_id)
      end

      it "creates ExParteActivity records for hourly activities" do
        expect {
          service.call
        }.to change(ExParteActivity, :count).from(0).to(1)

        activity = ExParteActivity.last
        expect(activity.member_id).to eq(member_id)
        expect(activity.category).to eq("employment")
        expect(activity.hours).to eq(40)
        expect(activity.period_start).to eq(certification_date.beginning_of_month)
        expect(activity.period_end).to eq(certification_date.end_of_month)
        expect(activity.source_type).to eq("api")
        expect(activity.source_id).to be_nil
      end

      it "creates a CertificationOrigin record" do
        expect {
          service.call
        }.to change(CertificationOrigin, :count).from(0).to(1)

        origin = CertificationOrigin.last
        expect(origin.certification_id).to eq(service.certification.id)
        expect(origin.source_type).to eq(CertificationOrigin::SOURCE_TYPE_API)
        expect(origin.source_id).to be_nil
      end

      it "does not include employer in ExParteActivity" do
        service.call
        activity = ExParteActivity.last
        expect(activity).not_to respond_to(:employer)
      end

      it "does not include verification_status in ExParteActivity" do
        service.call
        activity = ExParteActivity.last
        expect(activity).not_to respond_to(:verification_status)
      end
    end

    context "with multiple hourly activities" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            },
            {
              "type" => "hourly",
              "category" => "community_service",
              "hours" => 10,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
      end

      it "creates ExParteActivity records for all hourly activities" do
        expect {
          service.call
        }.to change(ExParteActivity, :count).from(0).to(2)

        activities = ExParteActivity.where(member_id: member_id).order(:category)
        expect(activities.first.category).to eq("community_service")
        expect(activities.last.category).to eq("employment")
      end
    end

    context "with income activities" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "income",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
      end

      it "does not create ExParteActivity records for income activities" do
        expect {
          service.call
        }.not_to change(ExParteActivity, :count)
      end

      it "still creates the certification" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)
      end
    end

    context "with mixed hourly and income activities" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => 40,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            },
            {
              "type" => "income",
              "category" => "employment",
              "hours" => 20,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
      end

      it "creates ExParteActivity only for hourly activities" do
        expect {
          service.call
        }.to change(ExParteActivity, :count).from(0).to(1)

        activity = ExParteActivity.last
        expect(activity.hours).to eq(40)
      end
    end

    context "with no activities" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: nil
        )
      end

      it "does not create ExParteActivity records" do
        expect {
          service.call
        }.not_to change(ExParteActivity, :count)
      end

      it "still creates the certification" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)
      end
    end

    context "with empty activities array" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: []
        )
      end

      it "does not create ExParteActivity records" do
        expect {
          service.call
        }.not_to change(ExParteActivity, :count)
      end

      it "still creates the certification" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)
      end
    end

    context "when ExParteActivity validation fails" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => "employment",
              "hours" => -10, # Invalid: negative hours
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month
            }
          ]
        )
      end

      it "raises ActiveRecord::RecordInvalid and does not create records (rollback)" do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Certification.count).to eq(0)
        expect(ExParteActivity.count).to eq(0)
        expect(CertificationOrigin.count).to eq(0)
      end
    end
  end
end
