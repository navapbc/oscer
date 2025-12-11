# frozen_string_literal: true

FactoryBot.define do
  factory :ex_parte_activity do
    member_id { Faker::NationalHealthService.british_number }
    category { ExParteActivity::ALLOWED_CATEGORIES.sample }
    hours { Faker::Number.between(from: 1.0, to: 200.0).round(2) }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    source_type { ExParteActivity::SOURCE_TYPES[:api] }
    source_id { nil }

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
      source_type { ExParteActivity::SOURCE_TYPES[:batch] }
      source_id { SecureRandom.uuid }
    end
  end
end
