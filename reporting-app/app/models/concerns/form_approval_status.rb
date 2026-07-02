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

  included do
    # The review-task class is recorded as a String and resolved lazily (see review_task_class).
    # Resolving eagerly here would risk a Zeitwerk load cycle: a review-task class may reference
    # its form class in its own body (e.g. ReviewExemptionClaimTask -> ExemptionApplicationForm).
    class_attribute :review_task_class_name, instance_accessor: false
  end

  class_methods do
    # Each form binds to its own review-task subclass; the association config is shared.
    def has_review_task(class_name)
      self.review_task_class_name = class_name
      has_one :review_task,
        class_name: class_name,
        foreign_key: :application_form_id,
        inverse_of: :application_form,
        strict_loading: false
    end

    # The bound review-task class; fails loud if a form forgot has_review_task.
    def review_task_class
      review_task_class_name&.constantize or
        raise NotImplementedError, "#{name} must declare has_review_task"
    end
  end

  def approval_status = review_task&.approval_status
  def approved? = review_task&.approved?
  def denied? = review_task&.denied?
end
