# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    month { Date.today.prev_month.beginning_of_month }
    name { Faker::Company.name }
    category { Activity::ALLOWED_CATEGORIES.sample }

    trait :ai_assisted do
      evidence_source { "ai_assisted" }
    end

    trait :ai_assisted_with_member_edits do
      evidence_source { "ai_assisted_with_member_edits" }
    end

    trait :ai_rejected do
      evidence_source { "ai_rejected_member_override" }
    end

    factory :hourly_activity, parent: :activity, class: HourlyActivity do
      type { "HourlyActivity" }
      hours { Faker::Number.between(from: 1.0, to: 100.0) }
    end

    factory :work_activity, parent: :hourly_activity, class: WorkActivity do
      type { "WorkActivity" }
      hours { Faker::Number.between(from: 1.0, to: 100.0) }
    end

    factory :income_activity, parent: :activity, class: IncomeActivity do
      type { "IncomeActivity" }
      income { Faker::Number.between(from: 100, to: 5000) * 100 } # stored in cents
    end
  end
end
