# frozen_string_literal: true

FactoryBot.define do
  factory :certification_certification_requirement_params, class: Certifications::RequirementParams do
    certification_date { Faker::Date.forward(days: 30) }

    trait :with_certification_type do
      certification_type { Certifications::Requirements::CERTIFICATION_TYPE_OPTIONS.sample }
    end

    trait :with_direct_params do
      number_of_months_to_certify { Faker::Number.within(range: 1..3) }
      lookback_period { Faker::Number.within(range: 3..6) }

      due_date { nil }
      due_period_days { Faker::Number.within(range: 15..60) }
    end

    trait :with_due_date do
      due_date { Faker::Date.between(from: 30.days.from_now, to: 60.days.from_now) }
      due_period_days { nil }
    end
  end
end
