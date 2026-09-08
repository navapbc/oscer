# frozen_string_literal: true

FactoryBot.define do
  # The base factory carries neither value, so it is deliberately invalid on its own: a row must
  # report hours, income, or both. Always build with :with_hours, :with_income,
  # :with_hours_and_income, or :household.
  factory :external_activity do
    member_id { Faker::NationalHealthService.british_number }
    # Not ALLOWED_CATEGORIES: "household" belongs to income-only rows, so :household sets it.
    category { ActivityCategories::ALL.sample }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    source_type { ExternalActivity::SOURCE_TYPES[:api] }
    source_id { nil }
    reported_at { Time.current }
    metadata { {} }

    trait :with_hours do
      hours { Faker::Number.between(from: 1.0, to: 200.0).round(2) }
    end

    trait :with_income do
      gross_income { Faker::Number.between(from: 1.0, to: 10_000.0).round(2) }
    end

    trait :with_hours_and_income do
      with_hours
      with_income
    end

    trait :household do
      category { ExternalActivity::CATEGORY_HOUSEHOLD }
      with_income
    end

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
      source_type { ExternalActivity::SOURCE_TYPES[:batch] }
      source_id { SecureRandom.uuid }
    end
  end
end
