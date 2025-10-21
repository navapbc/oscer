class EarnedIncomeActivity < Activity
  include Strata::Attributes

  strata_attribute :earned_income, :money
end
