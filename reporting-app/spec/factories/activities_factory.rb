# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    association :activity_report_application_form
    month { Date.today.prev_month.beginning_of_month }
    name { Faker::Company.name }

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
