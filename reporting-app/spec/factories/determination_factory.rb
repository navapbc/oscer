# frozen_string_literal: true

FactoryBot.define do
  factory :determination do
    subject { association :certification }
    decision_method { 'automated' }
    reason { 'age_under_19_exempt' }
    outcome { 'exempt' }
    determination_data { { reasons: { rule: 'passed' } } }
    determined_at { Time.current }
  end
end
