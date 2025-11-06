# frozen_string_literal: true

FactoryBot.define do
  factory :certification_batch_upload do
    filename { "test_upload.csv" }
    status { :pending }
    association :uploader, factory: :user

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
      num_rows { 10 }
      num_rows_processed { 5 }
    end

    trait :completed do
      status { :completed }
      num_rows { 10 }
      num_rows_processed { 10 }
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
