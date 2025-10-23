# frozen_string_literal: true

class Api::Certifications::Response < ValueObject
  attribute :id, :string
  attribute :member_id, :string
  attribute :case_number, :string

  attribute :certification_requirements, Certifications::Requirements.to_type
  attribute :member_data, Certifications::MemberData.to_type

  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  def self.from_certification(certification)
    self.new_filtered(certification)
  end
end
