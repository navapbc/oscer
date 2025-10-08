# frozen_string_literal: true

class Api::Certifications::CreateRequest
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  attribute :member_id, :string
  attribute :case_number, :string

  attribute :certification_requirements, Certifications::RequirementParamsType.new
  attribute :member_data, Certifications::MemberDataType.new

  validates :certification_requirements, presence: true

  def self.from_request_params(params)
    self.new_filtered(params)
  end
end
