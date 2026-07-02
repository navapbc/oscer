# frozen_string_literal: true

# Abstract base for OSCER's application forms, all of which are bound to a CertificationCase.
# It holds the case-bound lifecycle those forms share — creation guards, pending-form detection,
# flow status, and event routing — so each concrete subclass carries only its own fields plus two
# bindings:
#
#   * +has_review_task "ReviewXTask"+  (from FormApprovalStatus) — the review-task class
#   * +case_approval_status :x_approval_status+                   — the CertificationCase accessor
#     that flow_status reads once staff review completes
#
# Mirrors the OscerTask -> Review*Task hierarchy in naming (Oscer + the Strata base name), but is
# +abstract_class = true+ rather than STI: Strata::ApplicationForm is itself abstract and each form
# has its own table (no +type+ column), so table names resolve from the concrete subclass and the
# status enum / attributes / determinations inherit normally.
class OscerApplicationForm < Strata::ApplicationForm
  self.abstract_class = true

  include FormApprovalStatus

  # Stored as a symbol and read lazily; see case_approval_status_accessor below.
  class_attribute :case_approval_status_accessor_name, instance_accessor: false

  class << self
    # Declares which CertificationCase approval-status accessor flow_status reads for this form
    # once its review task is complete (e.g. :activity_report_approval_status).
    def case_approval_status(accessor)
      self.case_approval_status_accessor_name = accessor
    end

    # Fail loud if a subclass forgot the binding, rather than silently resolving nil.
    def case_approval_status_accessor
      case_approval_status_accessor_name or
        raise NotImplementedError, "#{name} must declare case_approval_status"
    end

    # A case is blocked from a new form while one is in progress, or while a submitted form's
    # review task has not yet been resolved (still on hold or pending).
    def has_pending_form(certification_case_id)
      where(certification_case_id:, status: :in_progress).exists? ||
        review_task_class.where(
          application_form: where(certification_case_id:).all,
          status: [ :on_hold, :pending ]
        ).exists?
    end
  end

  validates :certification_case_id, presence: true
  validate :case_not_closed, on: :create
  validate :no_pending_forms, on: :create

  # Once staff review is complete the form's status defers to the case-level approval outcome;
  # until then it reports its own submit status. Memoization intentionally re-computes while the
  # resolved value is blank (task complete but the case accessor not yet written) — do not
  # simplify to +||=+, which would change that behavior.
  def flow_status
    unless @flow_status.present?
      @flow_status = if review_task_completed?
                       CertificationCase.find(certification_case_id).public_send(self.class.case_approval_status_accessor)
      else
                       status
      end
    end

    @flow_status
  end

  protected

  # Include the case id so the Created/Submitted events route to the case in the business process.
  def event_payload
    super.merge(case_id: certification_case_id)
  end

  private

  # True once this form's own review task has been completed by staff.
  def review_task_completed?
    self.class.review_task_class.where(
      case_id: certification_case_id,
      application_form: self,
      status: :completed
    ).exists?
  end

  def case_not_closed
    certification_case = CertificationCase.find_by(id: certification_case_id)
    if certification_case.blank?
      errors.add(:certification_case_id, "is invalid")
    elsif certification_case.closed?
      errors.add(:certification_case_id, "has closed")
    elsif certification_case.verification_window_ended?
      errors.add(:certification_case_id, "verification window has ended")
    end
  end

  def no_pending_forms
    errors.add(:certification_case_id, "has already been taken") if self.class.has_pending_form(certification_case_id)
  end
end
