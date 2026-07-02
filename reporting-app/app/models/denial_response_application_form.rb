# frozen_string_literal: true

# A denial response is a lightweight way for a member to resolve a denied certification case while
# their verification window is still open: a short written comment plus optional supporting
# documents that a staff reviewer approves or denies.
class DenialResponseApplicationForm < OscerApplicationForm
  has_review_task "ReviewDenialResponseTask"
  case_approval_status :denial_response_approval_status

  strata_attribute :comment, :text

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents.includes(:determinations) }
end
