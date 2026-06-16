# frozen_string_literal: true

# A denial response is a lightweight way for a member to resolve a denied certification case while
# their verification window is still open: a short written comment plus optional supporting
# documents that a staff reviewer approves or denies. Mirrors the activity-report and exemption
# application-form flows.
class DenialResponseApplicationForm < Strata::ApplicationForm
  include FormApprovalStatus
  has_review_task "ReviewDenialResponseTask"

  strata_attribute :comment, :text

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents.includes(:determinations) }

  validates :certification_case_id, presence: true
  validate :case_not_closed, on: :create
  validate :no_pending_forms, on: :create

  # Include the case id so the submitted event routes to the case in the business process.
  def event_payload
    super.merge(case_id: certification_case_id)
  end

  def flow_status
    unless @flow_status.present?
      task_complete = ReviewDenialResponseTask.where(case_id: certification_case_id,
                                                     application_form: self,
                                                     status: :completed).exists?
      @flow_status = if task_complete
                       CertificationCase.find(certification_case_id).denial_response_approval_status
      else
                       status
      end
    end

    @flow_status
  end

  # A new denial response is blocked only while a denial-response review is still open for the case
  # (an in-progress draft or a pending/on_hold review task). The broader "one pending review at a
  # time" gating across all form types is a later story.
  def self.has_pending_form(certification_case_id)
    DenialResponseApplicationForm.where(certification_case_id:, status: :in_progress).exists? ||
    ReviewDenialResponseTask.where(application_form: DenialResponseApplicationForm.where(certification_case_id:).all,
                                   status: [ :on_hold, :pending ]).exists?
  end

  private

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
    errors.add(:certification_case_id, "has already been taken") if DenialResponseApplicationForm.has_pending_form(certification_case_id)
  end
end
