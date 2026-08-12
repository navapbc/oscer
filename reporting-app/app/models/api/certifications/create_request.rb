# frozen_string_literal: true

class Api::Certifications::CreateRequest < ValueObject
  attribute :member_id, :string
  attribute :case_number, :string
  attribute :application_date, :date

  attribute :certification_requirements, Api::Certifications::RequirementsOrParamsInput.to_type
  attribute :member_data, Certifications::MemberData.to_type
  attribute :household_data, Certifications::HouseholdData.to_type

  validates :certification_requirements, presence: true

  def self.from_request_params(params)
    new_filtered(params)
  end

  def to_certification
    case certification_requirements
    when Certifications::Requirements
      # we are good to go
      certification_requirements = self.certification_requirements
    when Certifications::RequirementParams
      certification_requirements = self.certification_requirements.to_requirements
    else
      # this should never be reached, something in the code is wrong
      raise TypeError
    end

    cert_attrs = attributes.merge({ certification_requirements: certification_requirements })
    Certification.new(cert_attrs)
  end
end
