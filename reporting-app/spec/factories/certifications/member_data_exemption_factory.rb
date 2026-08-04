# frozen_string_literal: true

FactoryBot.define do
  factory :certification_member_data_exemption, class: Certifications::MemberData::Exemption do
    skip_create

    transient do
      cert_date { Date.new(2025, 7, 20) }
    end

    type { 'exemption_type' }
    trait :valid do
      value { true }
      verification_status { 'verified' }
    end
    trait :period_end_valid do
      valid
      periods do
        [
          {
            "period_start": cert_date - 2.months,
            "period_end": cert_date + 1.month
          }
        ]
      end
    end
    trait :period_end_invalid do
      valid
      periods do
        [
          {
            "period_start": cert_date - 2.months,
            "period_end": cert_date - 1.month
          }
        ]
      end
    end
  end
end
