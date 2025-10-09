# frozen_string_literal: true

class Certifications::RequirementTypeParams < ValueObject
  include ::JsonHash

  attribute :lookback_period, :integer
  attribute :number_of_months_to_certify, :integer
  attribute :due_period_days, :integer
end
