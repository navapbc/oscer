class EarnedIncomeActivity < Activity
  include Strata::Attributes

  strata_attribute :earned_income, :money
  validates :earned_income, presence: true, numericality: { greater_than: 0 }
end
