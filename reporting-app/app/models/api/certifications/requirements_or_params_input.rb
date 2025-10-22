# frozen_string_literal: true

class Api::Certifications::RequirementsOrParamsInput < UnionObject
  include ActiveModel::AsJsonAttributeType

  def self.union_types
    [ Api::Certifications::Requirements,
      Api::Certifications::RequirementParams
    ]
  end
end
