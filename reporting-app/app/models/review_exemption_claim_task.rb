# frozen_string_literal: true

class ReviewExemptionClaimTask < OscerTask
  before_validation :ensure_application_form

  belongs_to :application_form, class_name: ExemptionApplicationForm.name, strict_loading: false

  def self.application_form_class
    ExemptionApplicationForm
  end
end
