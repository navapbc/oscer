# frozen_string_literal: true

FactoryBot.define do
  factory :certification_certification_requirements, class: Certifications::Requirements do
    certification_date { Faker::Date.forward(days: 30) }
    number_of_months_to_certify { Faker::Number.within(range: 1..3) }
    months_that_can_be_certified do
      Faker::Number.between(
        from: number_of_months_to_certify,
        to: number_of_months_to_certify + 3
      ).times.map { |i| certification_date.beginning_of_month << i }
    end
    due_date { Faker::Date.between(from: 30.days.from_now, to: 60.days.from_now) }

    # TODO: trait for certification type
  end
end
