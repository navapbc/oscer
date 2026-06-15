# frozen_string_literal: true

class ReviewActivityReportTask < OscerTask
  before_validation :ensure_application_form

  belongs_to :application_form, class_name: ActivityReportApplicationForm.name, inverse_of: :review_task, strict_loading: false

  # Records the staff review decision. Nil until decided, distinguishable from approved/denied.
  enum :approval_status, { approved: "approved", denied: "denied" }

  def self.application_form_class
    ActivityReportApplicationForm
  end
end
