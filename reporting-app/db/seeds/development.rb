# frozen_string_literal: true

# Disable email delivery during seeding to prevent letter_opener from opening browser tabs
original_delivery_method = ActionMailer::Base.delivery_method
ActionMailer::Base.delivery_method = :test

# Create sample batch uploads for testing
user = User.first || FactoryBot.create(:user, :as_admin, region: "Southeast", email: "staff@example.com")

5.times do |index|
  certification = FactoryBot.create(
    :certification,
    member_data: FactoryBot.build(:certification_member_data, :with_full_name, :with_account_email),
    certification_requirements: FactoryBot.build(:certification_certification_requirements, region: "Southeast")
  )
  certification_case = CertificationCase.find_by!(certification_id: certification.id)

  # Add ex parte activities (state-provided hours) for most cases
  unless index == 0 # Skip first case to test empty state
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback&.start ? Date.parse(lookback.start.to_s) : 2.months.ago.beginning_of_month.to_date
    period_end = lookback&.end ? Date.parse(lookback.end.to_s).end_of_month : 1.month.ago.end_of_month.to_date

    # Add 2-4 ex parte activities per case
    rand(2..4).times do
      ExParteActivity.create!(
        member_id: certification.member_id,
        category: ActivityCategories::ALL.sample,
        hours: rand(5..25),
        period_start: period_start,
        period_end: period_end,
        source_type: ExParteActivity::SOURCE_TYPES[:batch],
        source_id: "seed-#{SecureRandom.hex(4)}"
      )
    end
  end

  app_form = ActivityReportApplicationForm.create!(
    reporting_periods: [ { year: Date.today.prev_month.year, month: Date.today.prev_month.month } ],
    certification_case_id: certification_case.id,
    user_id: certification.member_id
  )

  next if index == 0 # Skip adding activities for the first form to test empty state

  app_form.activities.create!(
    name: "Community Meeting",
    type: "HourlyActivity",
    category: "community_service",
    month: Date.today.prev_month.beginning_of_month,
    hours: rand(1..5),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_paystub.png")), filename: "Courthouse Clerk Paystub.png", content_type: "image/png" }
    ]
  )
  app_form.activities.create!(
    name: "Outreach Event",
    type: "HourlyActivity",
    category: "community_service",
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
    category: "education",
    month: Date.today.prev_month.beginning_of_month,
    income: rand(15..300),
    supporting_documents: [
      { io: File.open(Rails.root.join("db/seeds/files/fake_training_certificate.pdf")), filename: "Training Certificate.pdf", content_type: "application/pdf" }
    ]
  )
  app_form.activities.create!(
    name: "Policy Discussion",
    type: "HourlyActivity",
    category: "community_service",
    month: Date.today.prev_month.prev_month.beginning_of_month,
    hours: rand(1..10)
  )
  app_form.activities.create!(
    name: "Volunteer Coordination",
    type: "HourlyActivity",
    category: "community_service",
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

# Restore original delivery method
ActionMailer::Base.delivery_method = original_delivery_method
