# frozen_string_literal: true

FactoryBot.define do
  factory :certification_case do
    business_process_current_step { "report_activities" }

    transient do
      certification { create(:certification) }
    end

    initialize_with {
      CertificationCase.find_or_create_by!(certification_id: certification.id)
    }

    trait :with_closed_status do
      after(:build) do |case_obj|
        case_obj.close
      end
    end

    trait :waiting_on_member do
      business_process_current_step { "report_activities" }
    end

    trait :actionable do
      business_process_current_step { "review_activity_report" }
      after(:create) do |case_obj|
        create(:review_activity_report_task, case: case_obj)
      end
    end
  end
end
