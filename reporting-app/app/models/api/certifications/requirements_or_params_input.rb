# frozen_string_literal: true

class Api::Certifications::RequirementTypeInput < ValueObject
  include ::JsonHash

  attribute :certification_date, :date
  attribute :certification_type, :string

  validates :certification_date, presence: true
  validates :certification_type, presence: true
end

class Api::Certifications::RequirementsOrParamsInput < UnionObject
  include ::JsonHash

  def self.union_types
    [ Certifications::Requirements,
      Certifications::RequirementParams,
      Api::Certifications::RequirementTypeInput
    ]
  end
end
