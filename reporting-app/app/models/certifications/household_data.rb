# frozen_string_literal: true

class Certifications::HouseholdData < ValueObject
  include ActiveModel::AsJsonAttributeType
  include Strata::Attributes

  class Member < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :name, ActiveModel::Type::Json.new(Strata::Name)
    attribute :ssn, :string
    attribute :date_of_birth, :date
    attribute :monthly_income_dollars_total, :decimal
  end

  attribute :members, :array, of: Member.to_type
end
