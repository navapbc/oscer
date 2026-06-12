# frozen_string_literal: true

# Exposes an application form's own determination outcome (approved/denied) without
# mutating the immutable form. The decision is recorded on the form's review task; the
# form simply delegates to it. A form with no review task, or whose review task is still
# undecided, reports no outcome (nil), distinguishable from approved/denied.
#
# Including models bind their review task with +has_review_task+, supplying the bound
# ReviewActivityReportTask / ReviewExemptionClaimTask class.
module FormApprovalStatus
  extend ActiveSupport::Concern

  class_methods do
    # Each form binds to its own review-task subclass; the association config is shared.
    def has_review_task(class_name)
      has_one :review_task,
        class_name: class_name,
        foreign_key: :application_form_id,
        inverse_of: :application_form,
        strict_loading: false
    end
  end

  def approval_status = review_task&.approval_status
  def approved? = approval_status == "approved"
  def denied? = approval_status == "denied"
end
