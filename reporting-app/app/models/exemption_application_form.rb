# frozen_string_literal: true

class ExemptionApplicationForm < OscerApplicationForm
  has_review_task "ReviewExemptionClaimTask"
  case_approval_status :exemption_request_approval_status

  # TODO: Remove when revising the old exemption screener flow
  LEGACY_EXEMPTION_TYPES = %w[short_term_hardship incarceration].freeze

  enum :exemption_type, Exemption.enum_hash
  validates :exemption_type, inclusion: { in: Exemption.types + LEGACY_EXEMPTION_TYPES }, allow_nil: true

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents.includes(:determinations) }

  strata_attribute :exemption_type, :string

  def self.information_request_class
    ExemptionInformationRequest
  end

  # True when caseworker review for this form has finished (+ReviewExemptionClaimTask+ completed).
  # Case-level +exemption_request_approval_status+ applies only after this; a new submission
  # after a prior denial stays pending until staff review the new request. Public delegator over
  # the base's review-task check; has external callers (member dashboard compliance).
  def staff_exemption_review_complete?
    review_task_completed?
  end
end
