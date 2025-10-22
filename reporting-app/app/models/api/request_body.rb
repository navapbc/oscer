# frozen_string_literal: true

module Api::RequestBody
  module Validations
    extend ActiveSupport::Concern

    include ActiveModel::Validations
    include ActiveRecord::AttributeMethods::BeforeTypeCast

    included do
      validates_with ActiveModel::Validations::NestedAttributeValidator
      validates_with ActiveModel::Validations::AttributesTypeValidator
    end
  end

  module ExtendedBehavior
    extend ActiveSupport::Concern

    include ActiveModel::NewFiltered
  end

  module ModelUtils
    extend ActiveSupport::Concern

    include Validations
    include ExtendedBehavior
  end

  class Model < Strata::ValueObject
    include ModelUtils

    include ActiveModel::Validations::Callbacks
  end
end
