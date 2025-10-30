# frozen_string_literal: true

FactoryBot.define do
  factory :exemption_application_form do
    exemption_type { "short_term_hardship" }
    certification_case_id { create(:certification_case, certification: create(:certification)).id }

    trait :with_supporting_documents do
      after(:build) do |form|
        form.supporting_documents.attach([
          fixture_file_upload('spec/fixtures/files/test_document_1.pdf', 'application/pdf'),
          fixture_file_upload('spec/fixtures/files/test_document_2.txt', 'text/plain')
        ])
      end
    end

    trait :incarceration do
      exemption_type { "incarceration" }
    end

    trait :with_submitted_status do
      after(:create) do |exemption_application_form|
        exemption_application_form.submit_application
      end
    end
  end
end
