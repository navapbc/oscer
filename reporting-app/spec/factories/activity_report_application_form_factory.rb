# frozen_string_literal: true

FactoryBot.define do
  factory :activity_report_application_form do
    id { SecureRandom.uuid }
    activities { [] }
    certification_case_id { create(:certification_case, certification: create(:certification)).id }

    trait :with_activities do
      after(:create) do |activity_report_application_form|
        activity_report_application_form.activities = create_list(
          :activity, 3, activity_report_application_form_id: activity_report_application_form.id
        )
      end
    end

    trait :with_submitted_status do
      after(:create) do |activity_report_application_form|
        activity_report_application_form.submit_application
      end
    end
  end
end
