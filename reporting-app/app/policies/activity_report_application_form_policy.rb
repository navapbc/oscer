# frozen_string_literal: true

class ActivityReportApplicationFormPolicy < ApplicationPolicy
  include Strata::ApplicationFormPolicy

  alias_method :doc_ai_upload?, :edit?
end
