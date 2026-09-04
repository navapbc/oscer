# frozen_string_literal: true

require_relative "certifications/member_data"
require_relative "certifications/requirements"
require_relative "certifications/household_data"

class Certification < ApplicationRecord
  include Determinable

  attribute :member_id, :string
  attribute :case_number, :string

  attribute :certification_requirements, Certifications::Requirements.to_type
  attribute :member_data, Certifications::MemberData.to_type
  attribute :household_data, Certifications::HouseholdData.to_type

  # TODO: some of this should be required, but leaving it open at the moment
  # validates :member_id, presence: true
  validates :certification_requirements, presence: true

  scope :by_member_id, ->(member_id) { where(member_id:) }
  scope :by_region, ->(region) { where("certification_requirements->>'region' = ?", region) }

  after_create_commit do
    Strata::EventManager.publish("CertificationCreated", { certification_id: id })
  end

  def member_account_email
    self&.member_data&.account_email
  end

  def self.find_by_member_account_email(email)
    where("member_data->>'account_email' = :email", email: email)
  end

  def member_contact_email
    self&.member_data&.contact&.email
  end

  def self.find_by_member_contact_email(email)
    where("member_data->'contact'->>'email' = :email", email: email)
  end

  def member_email
    member_account_email || member_contact_email
  end

  def outcome
    @outcome ||= Api::Certifications::Outcome.from_certification(self)
  end

  def self.find_by_member_email(email)
    find_by_member_account_email(email).or(find_by_member_contact_email(email))
  end

  # Check if certification exists with compound key (for duplicate prevention)
  def self.exists_for?(member_id:, case_number:, certification_date:)
    where(
      member_id: member_id,
      case_number: case_number
    ).where("certification_requirements->>'certification_date' = ?", certification_date.to_s).exists?
  end

  # Find an existing certification matching the API duplicate key
  # (member_id + case_number + application_date). Used to make
  # POST /api/certifications idempotent for state-system integrations.
  # Returns nil if any key component is blank so unrelated records with
  # missing values are never treated as duplicates. application_date will
  # be required on create in a follow-up; keep this guard until then.
  def self.find_duplicate(member_id:, case_number:, application_date:)
    return nil if member_id.blank? || case_number.blank? || application_date.blank?

    where(member_id:, case_number:, application_date:).order(:created_at).first
  end

  # Find certifications created via batch upload
  def self.from_batch_upload(batch_upload_id)
    joins("INNER JOIN certification_origins ON certifications.id = certification_origins.certification_id")
      .where(certification_origins: { source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD, source_id: batch_upload_id })
  end

  # Get the origin/source of this certification
  def origin
    CertificationOrigin.find_by(certification_id: id)
  end

  def member_name
    self&.member_data&.name
  end

  def region
    certification_requirements&.region
  end

  # The month a member's exclusion status is evaluated for. Bound into the rules
  # engine as the `evaluated_month` fact, which resolves by matching the ruleset's
  # parameter name -- renaming one side without the other fails silently.
  def evaluated_month
    application_date&.beginning_of_month
  end
end
