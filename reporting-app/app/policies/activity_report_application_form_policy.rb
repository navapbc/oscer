# frozen_string_literal: true

class ActivityReportApplicationFormPolicy < ApplicationPolicy
  include Strata::ApplicationFormPolicy

  def create?
    true
  end
end
