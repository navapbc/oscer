# frozen_string_literal: true

class ReviewExemptionClaimTask < OscerTask
  before_validation :bind_application_form

  belongs_to :application_form, class_name: ExemptionApplicationForm.name

  def self.application_form_class
    ExemptionApplicationForm
  end

  private

  def bind_application_form
    return if application_form_id

    application_forms = ExemptionApplicationForm.joins("LEFT JOIN strata_tasks ON exemption_application_forms.id = strata_tasks.application_form_id")
                          .where("certification_case_id = ? AND strata_tasks.application_form_id IS NULL", case_id)
    self.application_form_id = application_forms.first&.id
  end
end
