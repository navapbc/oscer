# frozen_string_literal: true

FactoryBot.define do
  factory :staged_document do
    user_id { create(:user).id }
    status { "pending" }
    extracted_fields { {} }

    after(:build) do |staged_document|
      staged_document.file.attach(
        io: StringIO.new("%PDF-1.4 test payslip content"),
        filename: "test_payslip.pdf",
        content_type: "application/pdf"
      )
    end

    trait :validated do
      status { "validated" }
      doc_ai_job_id { SecureRandom.uuid }
      doc_ai_matched_class { "Payslip" }
      extracted_fields do
        {
          "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }
        }
      end
      validated_at { Time.current }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :failed do
      status { "failed" }
    end
  end
end
