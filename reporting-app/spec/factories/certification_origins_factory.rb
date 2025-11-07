# frozen_string_literal: true

FactoryBot.define do
  factory :certification_origin do
    association :certification
    source_type { CertificationOrigin::SOURCE_TYPE_MANUAL }
    source_id { nil }

    trait :batch_upload do
      source_type { CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD }
      association :source_batch_upload, factory: :certification_batch_upload, strategy: :create

      after(:build) do |origin, evaluator|
        origin.source_id = evaluator.source_batch_upload.id
      end
    end

    trait :manual do
      source_type { CertificationOrigin::SOURCE_TYPE_MANUAL }
      source_id { nil }
    end

    trait :api do
      source_type { CertificationOrigin::SOURCE_TYPE_API }
      source_id { SecureRandom.uuid }
    end
  end
end
