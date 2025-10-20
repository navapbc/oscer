# frozen_string_literal: true

# TODO: either move, or if we are going to allow users to specify a type +
# override some of the params, then this can go away
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
