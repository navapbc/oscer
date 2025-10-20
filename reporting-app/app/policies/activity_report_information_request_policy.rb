# frozen_string_literal: true

class ActivityReportInformationRequestPolicy < ApplicationPolicy
  include Strata::ApplicationFormPolicy

  def update?
    application_form = ActivityReportApplicationForm.find(record.application_form_id)
    application_form.user_id == user.id
  end
end
