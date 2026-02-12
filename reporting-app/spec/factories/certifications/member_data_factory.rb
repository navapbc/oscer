# frozen_string_literal: true

FactoryBot.define do
  factory :certification_member_data, class: Certifications::MemberData do
    skip_create

    transient do
      cert_date { Date.today }
      num_months { 1 }
    end

    trait :with_full_name do
      name { attributes_for(:name, :base, :with_middle) }
    end

    trait :with_name_parts do
      name { attributes_for(:name, :base) }
    end

    trait :with_middle_name do
      name { attributes_for(:name, :base, :with_middle) }
    end

    trait :with_account_email do
      account_email { Faker::Internet.email }
    end

    trait :with_icn do
      icn { "1012861229V078999" }
    end

    trait :with_no_exemptions do
      date_of_birth { cert_date - rand(19..64).years } # random age between 19 and 64 years old (ineligible for age exemption)
      pregnancy_status { false }
      race_ethnicity do
        (
          Demo::Certifications::BaseCreateForm::RACE_ETHNICITY_OPTIONS - [ "american_indian_or_alaska_native" ]
        ).sample
      end
    end

    trait :partially_met_work_hours_requirement do
      with_no_exemptions
      activities {
        [
          {
            "type": "hourly",
            "category": "employment",
            "hours": 10,
            "period_start": cert_date.beginning_of_month,
            "period_end": cert_date.end_of_month,
            "employer": "Acme",
            "verification_status": "verified"
          }
        ]
      }
    end

    trait :fully_met_work_hours_requirement do
      with_no_exemptions
      activities {
        num_months.times.map { |i|
          {
            "type": "hourly",
            "category": "employment",
            "hours": 80,
            "period_start": cert_date.beginning_of_month << i,
            "period_end": cert_date.end_of_month << i,
            "employer": "Acme",
            "verification_status": "verified"
          }
        }
      }
    end

    trait :meets_age_based_exemption_requirement do
      with_no_exemptions
      date_of_birth { cert_date - rand(1..18).years } # random age between 1 and 18 years old (eligible for age exemption)
    end

    trait :with_activities do
      activities {
        [
          {
            "type": "hourly",
            "category": "community_service",
            "hours": 20,
            "period_start": cert_date.beginning_of_month,
            "period_end": cert_date.end_of_month,
            "employer": "Community Center",
            "verification_status": "verified"
          }
        ]
      }
    end
  end
end
