# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    uid { Faker::Internet.uuid }
    provider { "factory_bot" }
    mfa_preference { "opt_out" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { "caseworker" }
    program { "Medicaid" }
    region { "Northwest" }
  end
end
