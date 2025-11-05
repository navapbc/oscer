# frozen_string_literal: true

class IncomeActivity < Activity
  include Strata::Attributes

  strata_attribute :income, :money
  validate :income_must_be_greater_than_zero

  protected

  def income_must_be_greater_than_zero
    if income.nil? || income <= Strata::Money.new(cents: 0)
      errors.add(:income, :greater_than, value: 0, count: 0)
    end
  end
end
