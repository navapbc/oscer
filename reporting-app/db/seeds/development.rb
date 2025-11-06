# frozen_string_literal: true

# Create sample batch uploads for testing
user = User.first || User.create!(email: "staff@example.com", uid: SecureRandom.uuid, provider: "login.gov")

5.times do |index|
  certification = FactoryBot.create(
    :certification,
    member_data: FactoryBot.build(:certification_member_data, :with_full_name, :with_account_email)
  )
  certification_case = CertificationCase.find_by!(certification_id: certification.id)
  app_form = ActivityReportApplicationForm.create!(
    reporting_periods: [ { year: Date.today.prev_month.year, month: Date.today.prev_month.month } ],
    certification_case_id: certification_case.id,
    user_id: certification.member_id
  )
  app_form.save!

  next if index == 0 # Skip adding activities for the first form to test empty state

  app_form.activities.create!(
    name: "Community Meeting",
    type: "WorkActivity",
    month: Date.today.prev_month.beginning_of_month,
    hours: rand(1..5),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Courthouse Clerk Paystub.png", content_type: "image/png" }
    ]
  )
  app_form.activities.create!(
    name: "Outreach Event",
    type: "WorkActivity",
    month: Date.today.prev_month.beginning_of_month,
    hours: rand(1..5),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.pdf")), filename: "Paystub1.pdf", content_type: "application/pdf" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Paystub2.png", content_type: "image/png" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Paystub3.png", content_type: "image/png" }
    ]
  )
  app_form.activities.create!(
    name: "Training Session",
    type: "IncomeActivity",
    month: Date.today.prev_month.beginning_of_month,
    income: rand(15..300),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_training_certificate.pdf")), filename: "Training Certificate.pdf", content_type: "application/pdf" }
    ]
  )
  app_form.activities.create!(
    name: "Policy Discussion",
    type: "WorkActivity",
    month: Date.today.prev_month.prev_month.beginning_of_month,
    hours: rand(1..10)
  )
  app_form.activities.create!(
    name: "Volunteer Coordination",
    type: "WorkActivity",
    month: Date.today.prev_month.prev_month.beginning_of_month,
    hours: rand(15..60),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.pdf")), filename: "Administrative Paystub.pdf", content_type: "application/pdf" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.pdf")), filename: "Art Event Coordination Paystub.pdf", content_type: "application/pdf" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.pdf")), filename: "Food Bank Paystub.pdf", content_type: "application/pdf" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Food Bank Paystub 2.png", content_type: "image/png" },
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Trash Pickup Paystub.png", content_type: "image/png" }
    ]
  )
  app_form.save!

  app_form.submit_application
end

certifications = Certification.limit(4).to_a

# Pending batch
pending_batch = CertificationBatchUpload.new(
  filename: "pending_upload.csv",
  uploader: user,
  status: :pending
)
pending_batch.file.attach(
  io: StringIO.new("member_id,case_number,member_email\nM001,C-001,test1@example.com"),
  filename: "pending_upload.csv",
  content_type: "text/csv"
)
pending_batch.save!
CertificationOrigin.create!(
  certification_id: certifications.first.id,
  source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
  source_id: pending_batch.id
)

# Processing batch
processing_batch = CertificationBatchUpload.new(
  filename: "processing_upload.csv",
  uploader: user,
  status: :processing,
  num_rows: 100,
  num_rows_processed: 45
)
processing_batch.file.attach(
  io: StringIO.new("member_id,case_number,member_email\nM002,C-002,test2@example.com"),
  filename: "processing_upload.csv",
  content_type: "text/csv"
)
processing_batch.save!
CertificationOrigin.create!(
  certification_id: certifications.second.id,
  source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
  source_id: processing_batch.id
)

# Completed batch with successes
completed_batch = CertificationBatchUpload.new(
  filename: "completed_upload.csv",
  uploader: user,
  status: :completed,
  num_rows: 50,
  num_rows_processed: 50,
  num_rows_succeeded: 48,
  num_rows_errored: 2,
  processed_at: 1.hour.ago,
  results: {
    successes: [
      { row: 2, case_number: "C-100", member_id: "M100", certification_id: SecureRandom.uuid },
      { row: 3, case_number: "C-101", member_id: "M101", certification_id: SecureRandom.uuid }
    ],
    errors: [
      { row: 4, message: "Member can't be blank", data: { member_id: "", case_number: "C-102" } },
      { row: 25, message: "Duplicate: Certification already exists for member_id M100 and case_number C-100", data: { member_id: "M100", case_number: "C-100" } }
    ]
  }
)
completed_batch.file.attach(
  io: StringIO.new("member_id,case_number,member_email\nM003,C-003,test3@example.com"),
  filename: "completed_upload.csv",
  content_type: "text/csv"
  )
  completed_batch.save!
CertificationOrigin.create!(
  certification_id: certifications.third.id,
  source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
  source_id: completed_batch.id
)

# Failed batch
failed_batch = CertificationBatchUpload.new(
  filename: "failed_upload.csv",
  uploader: user,
  status: :failed,
  processed_at: 2.hours.ago,
  results: { error: "Invalid CSV format: Unclosed quoted field" }
)
failed_batch.file.attach(
  io: StringIO.new("invalid csv content"),
  filename: "failed_upload.csv",
  content_type: "text/csv"
)
failed_batch.save!
CertificationOrigin.create!(
  certification_id: certifications.last.id,
  source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
  source_id: failed_batch.id
)