# frozen_string_literal: true

FactoryBot.define do
  factory :income do
    member_id { Faker::NationalHealthService.british_number }
    category { Income::ALLOWED_CATEGORIES.sample }
    gross_income { Faker::Number.between(from: 1.0, to: 10_000.0).round(2) }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    source_type { Income::SOURCE_TYPES[:api] }
    source_id { nil }
    reported_at { Time.current }
    metadata { {} }

    trait :employment do
      category { 'employment' }
    end

    trait :community_service do
      category { 'community_service' }
    end

    trait :education do
      category { 'education' }
    end

    trait :from_batch do
      source_type { Income::SOURCE_TYPES[:batch_upload] }
      source_id { SecureRandom.uuid }
    end

    trait :from_quarterly_wage_data do
      source_type { Income::SOURCE_TYPES[:quarterly_wage_data] }
    end
  end
end
