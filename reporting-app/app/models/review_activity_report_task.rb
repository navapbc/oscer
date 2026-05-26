# frozen_string_literal: true

class ReviewActivityReportTask < OscerTask
  before_validation :ensure_application_form

  belongs_to :application_form, class_name: ActivityReportApplicationForm.name, strict_loading: false

  def self.application_form_class
    ActivityReportApplicationForm
  end
end
