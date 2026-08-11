# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::CreationService, type: :service do
  let(:member_id) { "member-123" }
  let(:case_number) { "case-456" }
  let(:certification_date) { Date.new(2025, 12, 25) }
  let(:household_data) { {} }

  let(:base_params) do
    {
      member_id: member_id,
      case_number: case_number,
      member_data: member_data.as_json,
      household_data: household_data.as_json,
      certification_requirements: build(:certification_certification_requirement_params,
        :with_direct_params,
        certification_date: certification_date
      ).as_json
    }
  end

  let(:create_request) { Api::Certifications::CreateRequest.new(**base_params) }
  let(:service) { described_class.new(create_request.to_certification) }

  describe "#call" do
    context "with hourly activities" do
      let(:verification_status) { "verified" }
      let(:category) { "employment" }
      let(:hours) { 40 }
      let(:credit_hours) { nil }
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "hourly",
              "category" => category,
              "hours" => hours,
              "credit_hours" => credit_hours,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "name" => "Acme Corp",
              "verification_status" => verification_status
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

      it "creates ExternalHourlyActivity records for hourly activities" do
        expect {
          service.call
        }.to change(ExternalHourlyActivity, :count).from(0).to(1)

        activity = ExternalHourlyActivity.last
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

      it "does not include employer in ExternalHourlyActivity" do
        service.call
        activity = ExternalHourlyActivity.last
        expect(activity).not_to respond_to(:employer)
      end

      it "does not include verification_status in ExternalHourlyActivity" do
        service.call
        activity = ExternalHourlyActivity.last
        expect(activity).not_to respond_to(:verification_status)
      end

      context "when verification status is not verified" do
        let(:verification_status) { "self_attested" }

        it "does not create ExternalHourlyActivity" do
          expect {
            service.call
          }.not_to change(ExternalHourlyActivity, :count)
        end
      end

      context "when education category and credit hours" do
        let(:credit_hours) { 9 }
        let(:category) { "education" }
        let(:hours) { nil }

        it "counts education hours at 13 to 1" do
          expect {
            service.call
          }.to change(ExternalHourlyActivity, :count).from(0).to(1)

          activity = ExternalHourlyActivity.last
          expect(activity.category).to eq("education")
          expect(activity.hours).to eq(
            credit_hours * Certifications::MemberData::Activity::CREDIT_HOURS_MULTIPLIER
          )
        end
      end

      context "when employment category and nil hours" do
        let(:category) { "employment" }
        let(:hours) { nil }

        it "raises ActiveRecord::RecordInvalid" do
          expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
        end
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
              "period_end" => certification_date.end_of_month,
              "verification_status" => "verified"
            },
            {
              "type" => "hourly",
              "category" => "community_service",
              "hours" => 10,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "verification_status" => "verified"
            }
          ]
        )
      end

      it "creates ExternalHourlyActivity records for all hourly activities" do
        expect {
          service.call
        }.to change(ExternalHourlyActivity, :count).from(0).to(2)

        activities = ExternalHourlyActivity.where(member_id: member_id).order(:category)
        expect(activities.first.category).to eq("community_service")
        expect(activities.last.category).to eq("employment")
      end
    end

    context "with income activities" do
      let(:verification_status) { "verified" }
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 620,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "source" => "api",
              "name" => "Acme Corp",
              "verification_status" => verification_status
            }
          ]
        )
      end

      it "does not create ExternalHourlyActivity records for income activities" do
        expect {
          service.call
        }.not_to change(ExternalHourlyActivity, :count)
      end

      it "creates ExternalIncomeActivity records for income activities" do
        expect {
          service.call
        }.to change(ExternalIncomeActivity, :count).from(0).to(1)

        expect(ExternalIncomeActivity.pluck(:member_id, :category, :gross_income, :source_type, :period_start, :period_end)).to eq(
          [
            [ member_id, "employment", 620, "api", certification_date.beginning_of_month, certification_date.end_of_month ]
          ]
        )
        expect(ExternalIncomeActivity.pick(:metadata)).to include("employer" => "Acme Corp")
      end

      it "still creates the certification" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)
      end

      context "when verification status is not verified" do
        let(:verification_status) { "pending" }

        it "does not create ExternalIncomeActivity" do
          expect {
            service.call
          }.not_to change(ExternalIncomeActivity, :count)
        end
      end
    end

    context "with household data" do
      let(:member_ssn) { "987654321" }
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          ssn: Strata::TaxId.new(member_ssn))
      end
      let(:household_data) do
        {
          members: [
            {
              name: {
                first: "Elizabeth",
                middle: "Frances",
                last: "Doe",
                suffix: ""
              },
              ssn: 'not-member-1',
              date_of_birth: "1979-09-01",
              gross_incomes: [
                {
                  gross_income:  "250.00",
                  period_start: "2025-11-01",
                  period_end: "2025-11-30"
                }
              ]
            },
            {
              name: {
                first: "Richard",
                middle: "Marcus",
                last: "Doe",
                suffix: ""
              },
              ssn: 'not-member-2',
              date_of_birth: "1983-10-02",
              gross_incomes: [
                {
                  gross_income:  "450.00",
                  period_start: "2025-10-01",
                  period_end: "2025-10-31"
                },
                {
                  gross_income:  "350.00",
                  period_start: "2025-11-01",
                  period_end: "2025-11-30"
                }
              ]
            }
          ]
        }
      end
      let(:applicant_block) do
        {
          name: {
            first: "Kitty",
            middle: "Gwendolyn",
            last: "Doe",
            suffix: ""
          },
          ssn: member_ssn,
          date_of_birth: "1967-01-22",
          gross_incomes: [
            {
              gross_income:  "150.00",
              period_start: "2025-11-01",
              period_end: "2025-11-30"
            }
          ]
        }
      end

      it "creates ExternalIncomeActivity for each hosehould member's gross monthly income" do
        expect {
          service.call
        }.to change(ExternalIncomeActivity, :count).from(0).to(3)
      end

      it "does not create ExternalIncomeActivity for applicant" do
        household_data[:members] << applicant_block
        expect {
          service.call
        }.to change(ExternalIncomeActivity, :count).from(0).to(3)
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
              "period_end" => certification_date.end_of_month,
              "verification_status" => "verified"
            },
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 580,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "source" => "api",
              "verification_status" => "verified"
            }
          ]
        )
      end

      it "creates ExternalHourlyActivity for hourly activities and ExternalIncomeActivity for income activities" do
        expect {
          service.call
        }.to change(ExternalHourlyActivity, :count).from(0).to(1)
          .and change(ExternalIncomeActivity, :count).from(0).to(1)

        eha = ExternalHourlyActivity.last
        expect(eha.hours).to eq(40)

        income = ExternalIncomeActivity.last
        expect(income.gross_income).to eq(580)
        expect(income.source_type).to eq("api")
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

      it "does not create ExternalHourlyActivity records" do
        expect {
          service.call
        }.not_to change(ExternalHourlyActivity, :count)
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

      it "does not create ExternalHourlyActivity records" do
        expect {
          service.call
        }.not_to change(ExternalHourlyActivity, :count)
      end

      it "still creates the certification" do
        expect {
          service.call
        }.to change(Certification, :count).from(0).to(1)
      end
    end

    context "when ExternalHourlyActivity validation fails" do
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
              "period_end" => certification_date.end_of_month,
              "verification_status" => "verified"
            }
          ]
        )
      end

      it "raises ActiveRecord::RecordInvalid and does not create records (rollback)" do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Certification.count).to eq(0)
        expect(ExternalHourlyActivity.count).to eq(0)
        expect(ExternalIncomeActivity.count).to eq(0)
        expect(CertificationOrigin.count).to eq(0)
      end
    end

    context "when ExternalIncomeActivityService fails (duplicate income in same request)" do
      let(:member_data) do
        build(:certification_member_data,
          :with_full_name,
          :with_account_email,
          activities: [
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 500,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "source" => "api",
              "verification_status" => "verified"
            },
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 500,
              "period_start" => certification_date.beginning_of_month,
              "period_end" => certification_date.end_of_month,
              "source" => "api",
              "verification_status" => "verified"
            }
          ]
        )
      end

      it "raises ActiveRecord::RecordInvalid and rolls back certification and partial income" do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Certification.count).to eq(0)
        expect(ExternalIncomeActivity.count).to eq(0)
        expect(CertificationOrigin.count).to eq(0)
      end
    end
  end
end
