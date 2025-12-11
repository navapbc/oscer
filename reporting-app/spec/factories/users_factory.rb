# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    uid { Faker::Internet.uuid }
    provider { "login.gov" }
    mfa_preference { "opt_out" }
    full_name { nil }
    role { nil }
    region { nil }

    trait :as_admin do
      role { "admin" }
    end

    trait :as_caseworker do
      role { "caseworker" }
    end
  end
end
