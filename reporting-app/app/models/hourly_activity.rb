# frozen_string_literal: true

class HourlyActivity < Activity
  include Strata::Attributes

  strata_attribute :hours, :decimal
  validates :hours, presence: true, numericality: { greater_than: 0 }
end
