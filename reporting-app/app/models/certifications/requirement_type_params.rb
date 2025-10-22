# frozen_string_literal: true

class Certifications::RequirementTypeParams < Strata::ValueObject
  include ActiveModel::AsJsonAttributeType

  attribute :lookback_period, :integer
  attribute :number_of_months_to_certify, :integer
  attribute :due_period_days, :integer

  def set_params_for_type(certification_type)
    type_params = self.class.cert_type_params_for(certification_type)

    if type_params.blank?
      return
    end

    self.lookback_period = type_params.lookback_period
    self.number_of_months_to_certify = type_params.number_of_months_to_certify

    self.due_period_days = type_params.due_period_days
  end

  def self.cert_type_params_for(certification_type)
    # TODO: can be updated to load from some config, the DB, etc.
    case certification_type
    when "new_application"
      self.new({
        lookback_period: 1,
        number_of_months_to_certify: 1,
        due_period_days: 30
      })
    when "recertification"
      self.new({
        lookback_period: 6,
        number_of_months_to_certify: 3,
        due_period_days: 30
      })
    else
      nil
      # TODO: Or?
      # raise ArgumentError, "Unknown certification type"
    end
  end
end
