# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    association :activity_report_application_form
    month { Date.today.prev_month.beginning_of_month }
    hours { Faker::Number.between(from: 1.0, to: 100.0) }
    name { Faker::Company.name }
  end
end
