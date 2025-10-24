# frozen_string_literal: true

class Api::Certifications::CreateRequest < Api::RequestBody::Model
  strata_attribute :member_id, :string
  strata_attribute :case_number, :string

  strata_attribute :certification_requirements, ActiveModel::Type::Json.new(UnionObject.build([ Api::Certifications::Requirements, Api::Certifications::RequirementParams ]))
  strata_attribute :member_data, Certifications::MemberData.to_type

  validates :certification_requirements, presence: true

  def self.from_request_params(params)
    self.new_filtered(params)
  end

  def to_certification
    case self.certification_requirements
    when Certifications::Requirements
      # we are good to go
      certification_requirements = self.certification_requirements
    when Certifications::RequirementParams
      certification_requirements = self.certification_requirements.to_requirements
    else
      # this should never be reached, something in the code is wrong
      raise TypeError
    end

    cert_attrs = self.attributes.merge({ certification_requirements: certification_requirements })
    Certification.new(cert_attrs)
  end
end
