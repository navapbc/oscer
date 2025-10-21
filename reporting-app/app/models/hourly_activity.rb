class HourlyActivity < Activity
  include Strata::Attributes

  strata_attribute :hours, :decimal
end
