# frozen_string_literal: true

# Model for a Medicaid member.
# Eventually this will be a full active record model, but for now it's just a
# placeholder.
class Member < Strata::ValueObject
  include Strata::Attributes

  strata_attribute :member_id, :string
  strata_attribute :email, :string
  strata_attribute :name, :name

  # We won't need this method once we have a full active record model for member
  def self.from_certification(certification)
    Member.new(
      member_id: certification.member_id,
      email: certification.member_email,
      name: certification.member_name
    )
  end

  def self.find_by_member_id(member_id)
    certification = Certification.by_member_id(member_id).last!
    Member.from_certification(certification)
  end

  def self.search_by_email(email)
    certifications = Certification.find_by_member_email(email)
    certifications.map do |certification|
      Member.from_certification(certification)
    end
  end

  private

  def self.certification_service
    CertificationService.new
  end
end
