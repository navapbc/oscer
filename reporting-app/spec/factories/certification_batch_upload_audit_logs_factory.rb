# frozen_string_literal: true

FactoryBot.define do
  factory :certification_batch_upload_audit_log, aliases: [ :audit_log ] do
    association :certification_batch_upload
    chunk_number { 1 }
    status { :started }
    succeeded_count { 0 }
    failed_count { 0 }

    trait :completed do
      status { :completed }
      succeeded_count { 1000 }
      failed_count { 0 }
    end

    trait :failed do
      status { :failed }
    end
  end
end
