# frozen_string_literal: true

class Certifications::HouseholdData < ValueObject
  include ActiveModel::AsJsonAttributeType
  include Strata::Attributes

  class GrossIncome < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :gross_income, :decimal
    attribute :period_start, :date
    attribute :period_end, :date

    validates :gross_income, presence: true, numericality: { greater_than: 0 }
    validates :period_start, presence: true
    validates :period_end, presence: true
  end

  class Member < ValueObject
    include ActiveModel::AsJsonAttributeType
    include Strata::Attributes

    attribute :name, ActiveModel::Type::Json.new(Strata::Name)
    strata_attribute :ssn, :tax_id
    attribute :date_of_birth, :date
    attribute :gross_incomes, :array, of: GrossIncome.to_type

    # The applicant can also appear in household_data, where their income is already reported
    # through member_data and must not be counted twice. Tax ID is authoritative when both sides
    # have one; otherwise name and date of birth must both match to confirm the same person.
    def same_person_as?(member_data)
      return false if member_data.nil?
      return ssn == member_data.ssn if ssn.present? && member_data.ssn.present?

      same_name_as?(member_data.name) &&
        date_of_birth.present? &&
        date_of_birth == member_data.date_of_birth
    end

    private

    # Middle names and suffixes are reported inconsistently, so only first and last are compared.
    def same_name_as?(other_name)
      parts = name_parts(name)

      parts.none?(&:blank?) && parts == name_parts(other_name)
    end

    def name_parts(value)
      [ value&.first, value&.last ].map { |part| part.to_s.strip.downcase }
    end
  end

  attribute :members, :array, of: Member.to_type
end
