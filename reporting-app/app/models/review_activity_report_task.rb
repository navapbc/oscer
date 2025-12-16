# frozen_string_literal: true

class ReviewActivityReportTask < OscerTask
  def self.application_form_class
    ActivityReportApplicationForm
  end
end
