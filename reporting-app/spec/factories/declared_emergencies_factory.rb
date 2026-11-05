# frozen_string_literal: true

FactoryBot.define do
  factory :declared_emergency do
    origin_id { SecureRandom.uuid }
    fips_code { "000" }
    origin_raw { { id: origin_id } }
    period_start { 1.month.ago }
  end
end
