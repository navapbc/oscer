# frozen_string_literal: true

require_relative "certifications/member_data"
require_relative "certifications/requirements"

class Certification < ApplicationRecord
  attribute :member_id, :string
  attribute :case_number, :string

  attribute :certification_requirements, Certifications::Requirements.to_type
  attribute :member_data, Certifications::MemberData.to_type

  # TODO: some of this should be required, but leaving it open at the moment
  # validates :member_id, presence: true
  validates :certification_requirements, presence: true

  scope :by_member_id, ->(member_id) { where(member_id:) }

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
    self.member_account_email || self.member_contact_email
  end

  def self.find_by_member_email(email)
    self.find_by_member_account_email(email).or(self.find_by_member_contact_email(email))
  end

  # utilities derived from underlying data

  def member_name_strata
    self&.member_data&.name&.to_strata
  end
end
