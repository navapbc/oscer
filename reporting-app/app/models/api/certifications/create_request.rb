# frozen_string_literal: true

class Api::Certifications::CreateRequest < ValueObject
  attribute :member_id, :string
  attribute :case_number, :string

  attribute :certification_requirements, Certifications::RequirementParams.to_type
  attribute :member_data, Certifications::MemberData.to_type

  validates :certification_requirements, presence: true

  def self.from_request_params(params)
    self.new_filtered(params)
  end
end
