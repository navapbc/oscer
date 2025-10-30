# frozen_string_literal: true

class ExemptionApplicationFormPolicy < ApplicationPolicy
  include Strata::ApplicationFormPolicy

  alias_method :documents?, :edit?
  alias_method :upload_documents?, :edit?
end
