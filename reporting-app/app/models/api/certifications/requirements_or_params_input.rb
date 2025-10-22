# frozen_string_literal: true

class Api::Certifications::RequirementsOrParamsInput < UnionObject
  include ActiveModel::AsJsonAttributeType

  def self.union_types
    [ Certifications::Requirements,
      Certifications::RequirementParams
    ]
  end
end
