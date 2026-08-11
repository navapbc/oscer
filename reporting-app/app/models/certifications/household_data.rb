# frozen_string_literal: true

class Certifications::HouseholdData < ValueObject
  include ActiveModel::AsJsonAttributeType
  include Strata::Attributes

  class GrossIncome < ValueObject
    include ActiveModel::AsJsonAttributeType
    attribute :gross_income, :decimal
    attribute :period_start, :date
    attribute :period_end, :date
  end
  class Member < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :name, ActiveModel::Type::Json.new(Strata::Name)
    attribute :ssn, :string
    attribute :date_of_birth, :date
    attribute :gross_incomes, :array, of: GrossIncome.to_type
  end

  attribute :members, :array, of: Member.to_type
end
