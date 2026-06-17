# frozen_string_literal: true

FactoryBot.define do
  factory :denial_response_application_form do
    id { SecureRandom.uuid }
    comment { "Here is my explanation for why my case should be reconsidered." }
    certification_case_id { create(:certification_case, certification: create(:certification)).id }

    trait :with_submitted_status do
      after(:create) do |denial_response_application_form|
        denial_response_application_form.submit_application
      end
    end
  end
end
