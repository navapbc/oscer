# frozen_string_literal: true

FactoryBot.define do
  factory :certification_batch_upload_error, aliases: [ :upload_error ] do
    association :certification_batch_upload
    row_number { 1 }
    error_code { BatchUploadErrors::Validation::MISSING_FIELDS }
    error_message { "Missing required field" }
    row_data { { "member_id" => "M001" } }
  end
end
