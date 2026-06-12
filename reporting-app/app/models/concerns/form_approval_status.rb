# frozen_string_literal: true

# Exposes an application form's own determination outcome (approved/denied) without
# mutating the immutable form. The decision is recorded on the form's review task; the
# form simply delegates to it. A form with no review task, or whose review task is still
# undecided, reports no outcome (nil), distinguishable from approved/denied.
#
# Including models must declare a +review_task+ association (the bound
# ReviewActivityReportTask / ReviewExemptionClaimTask).
module FormApprovalStatus
  extend ActiveSupport::Concern

  def approval_status = review_task&.approval_status
  def approved? = approval_status == "approved"
  def denied? = approval_status == "denied"
end
