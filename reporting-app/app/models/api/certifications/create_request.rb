# frozen_string_literal: true

class Api::Certifications::CreateRequest < ValueObject
  attribute :member_id, :string
  attribute :case_number, :string
  attribute :application_date, :date

  attribute :certification_requirements, Api::Certifications::RequirementsOrParamsInput.to_type
  attribute :member_data, Certifications::MemberData.to_type
  attribute :household_data, Certifications::HouseholdData.to_type

  validates :certification_requirements, presence: true
  # application_date is a Certification attribute, not a RequirementParams one: RequirementParams'
  # valid? doubles as type dispatch (UnionObject#new), so presence-validating application_date
  # there would make every parameter-shaped request invalid, matching neither union member. See
  # RequirementParams#to_requirements.
  validates :application_date, presence: true
  validate :application_date_must_be_a_date

  def self.from_request_params(params)
    new_filtered(params)
  end

  def to_certification
    case certification_requirements
    when Certifications::Requirements
      # we are good to go
      certification_requirements = self.certification_requirements
    when Certifications::RequirementParams
      certification_requirements = self.certification_requirements.to_requirements(application_date:)
    else
      # this should never be reached, something in the code is wrong
      raise TypeError
    end

    cert_attrs = attributes.merge({ certification_requirements: certification_requirements })
    Certification.new(cert_attrs)
  end

  private

  # ActiveModel's date cast passes non-String values through untouched, so an
  # integer, float, or array would otherwise reach months_that_can_be_certified and crash it.
  def application_date_must_be_a_date
    return if application_date.nil? || application_date.is_a?(Date)

    errors.add(:application_date, :invalid)
  end
end
