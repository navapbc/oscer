# frozen_string_literal: true

class ExemptionInformationRequestPolicy < ApplicationPolicy
  include Strata::ApplicationFormPolicy

  def update?
    application_form = ExemptionApplicationForm.find(record.application_form_id)
    application_form.user_id == user.id
  end
end
