# frozen_string_literal: true

class Api::Certifications::Response < Strata::ValueObject
  # TODO: Or include Api::RequestBody::ExtendedBehavior/move that to a general api/model module?
  include ActiveModel::NewFiltered

  strata_attribute :id, :string
  strata_attribute :member_id, :string
  strata_attribute :case_number, :string

  strata_attribute :certification_requirements, Certifications::Requirements.to_type
  strata_attribute :member_data, Certifications::MemberData.to_type

  strata_attribute :created_at, :datetime
  strata_attribute :updated_at, :datetime

  def self.from_certification(certification)
    self.new_filtered(certification)
  end
end
