# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::CreationService, type: :service do
  let(:member_id) { "member-123" }
  let(:case_number) { "case-456" }
  let(:certification_date) { Date.new(2025, 12, 25) }
  let(:latest_certifiable_month) { certification_date << 1 }
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
      let(:enrollment_status) { nil }
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
              "enrollment_status" => enrollment_status,
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
        expect(activity.period_start).to eq(latest_certifiable_month.beginning_of_month)
        expect(activity.period_end).to eq(latest_certifiable_month.end_of_month)
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

      # Below half time is accepted as a no-op too, not rejected for the missing hours.
      %w[full_time less_than_half_time].each do |status|
        context "when education category reports #{status} enrollment without hours" do
          let(:category) { "education" }
          let(:hours) { nil }
          let(:enrollment_status) { status }

          it "creates the certification without an ExternalHourlyActivity" do
            expect { service.call }.to change(Certification, :count).from(0).to(1)

            expect(ExternalHourlyActivity.count).to be_zero
          end

          it "records the enrollment status on the certification's member data" do
            service.call

            activity = service.certification.member_data.activities.first
            expect(activity.enrollment_status).to eq(status)
          end
        end
      end

      context "when education category reports both enrollment and hours" do
        let(:category) { "education" }
        let(:hours) { 40 }
        let(:enrollment_status) { "full_time" }

        it "still imports the reported hours" do
          expect {
            service.call
          }.to change(ExternalHourlyActivity, :count).from(0).to(1)

          expect(ExternalHourlyActivity.last.hours).to eq(40)
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
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
              "verification_status" => "verified"
            },
            {
              "type" => "hourly",
              "category" => "community_service",
              "hours" => 10,
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
            [ member_id, "employment", 620, "api", latest_certifiable_month.beginning_of_month, latest_certifiable_month.end_of_month ]
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
      let(:member_ssn) { "000000001" }
      let(:member_name) { { first: "Kitty", middle: "Gwendolyn", last: "Doe", suffix: "" } }
      let(:member_date_of_birth) { "1967-01-22" }
      let(:member_data) do
        build(:certification_member_data,
          :with_account_email,
          ssn: member_ssn,
          name: member_name,
          date_of_birth: member_date_of_birth)
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
              ssn: "000000002",
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
              ssn: "000000003",
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
      let(:applicant_ssn) { member_ssn }
      let(:applicant_block) do
        {
          name: member_name,
          ssn: applicant_ssn,
          date_of_birth: member_date_of_birth,
          gross_incomes: [
            {
              gross_income:  "150.00",
              period_start: "2025-11-01",
              period_end: "2025-11-30"
            }
          ]
        }
      end

      it "creates an ExternalIncomeActivity for each household member's gross income" do
        expect {
          service.call
        }.to change(ExternalIncomeActivity, :count).from(0).to(3)

        expect(ExternalIncomeActivity.pluck(:gross_income)).to contain_exactly(250, 350, 450)
      end

      shared_examples "skips the applicant" do
        before { household_data[:members] << applicant_block }

        it "does not create an ExternalIncomeActivity for the applicant" do
          expect {
            service.call
          }.to change(ExternalIncomeActivity, :count).from(0).to(3)

          expect(ExternalIncomeActivity.pluck(:gross_income)).to contain_exactly(250, 350, 450)
        end
      end

      context "when the applicant is also listed as a household member" do
        it_behaves_like "skips the applicant"
      end

      context "when the applicant is listed with a dash-formatted tax ID" do
        let(:applicant_ssn) { "000-00-0001" }

        it_behaves_like "skips the applicant"
      end

      context "when the applicant is listed without a tax ID" do
        let(:applicant_ssn) { nil }

        it_behaves_like "skips the applicant"
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
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
              "verification_status" => "verified"
            },
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 580,
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
              "source" => "api",
              "verification_status" => "verified"
            },
            {
              "type" => "income",
              "category" => "employment",
              "gross_income" => 500,
              "period_start" => latest_certifiable_month.beginning_of_month,
              "period_end" => latest_certifiable_month.end_of_month,
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
