# frozen_string_literal: true

class IncomeActivity < Activity
  include Strata::Attributes

  strata_attribute :income, :money
  validate :income_must_be_greater_than_zero

  def update_with_doc_ai_review(attributes)
    return update(attributes) unless evidence_source == "ai_assisted"

    original_income_cents = income&.cents
    original_month = month

    self.attributes = attributes

    if income&.cents != original_income_cents || month != original_month
      self.evidence_source = "ai_assisted_with_member_edits"
    end

    save
  end

  protected

  def income_must_be_greater_than_zero
    if income.nil? || income <= Strata::Money.new(cents: 0)
      errors.add(:income, :greater_than, value: 0, count: 0)
    end
  end
end
