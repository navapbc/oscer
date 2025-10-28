# frozen_string_literal: true

FactoryBot.define do
  factory :certification_batch_upload do
    filename { "test_upload.csv" }
    status { :pending }
    association :uploaded_by, factory: :user

    after(:build) do |batch_upload|
      # Attach a dummy CSV file
      batch_upload.file.attach(
        io: StringIO.new("member_id,case_number\nM001,C-001"),
        filename: batch_upload.filename,
        content_type: 'text/csv'
      )
    end

    trait :processing do
      status { :processing }
      total_rows { 10 }
      processed_rows { 5 }
    end

    trait :completed do
      status { :completed }
      total_rows { 10 }
      processed_rows { 10 }
      success_count { 8 }
      error_count { 2 }
      processed_at { Time.current }
      results { { successes: [], errors: [] } }
    end

    trait :failed do
      status { :failed }
      processed_at { Time.current }
      results { { error: "Processing failed" } }
    end
  end
end
