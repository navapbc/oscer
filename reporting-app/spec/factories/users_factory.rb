# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    uid { Faker::Internet.uuid }
    provider { "factory_bot" }
    mfa_preference { "opt_out" }
  end
end
