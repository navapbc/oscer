# frozen_string_literal: true

class ExemptionApplicationForm < Strata::ApplicationForm
  # TODO: Remove when revising the old exemption screener flow
  LEGACY_EXEMPTION_TYPES = %w[short_term_hardship incarceration].freeze

  enum :exemption_type, Exemption.enum_hash
  validates :exemption_type, inclusion: { in: Exemption.types + LEGACY_EXEMPTION_TYPES }, allow_nil: true

  validate :case_not_closed, on: :create
  validate :no_pending_forms, on: :create

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents.includes(:determinations) }

  strata_attribute :exemption_type, :string

  def self.find_by_certification_case_id(certification_case_id)
    find_by(certification_case_id:)
  end

  def event_payload
    super.merge(case_id: certification_case_id)
  end

  def self.information_request_class
    ExemptionInformationRequest
  end

  def flow_status
    task_complete = ReviewExemptionClaimTask.where(case_id: certification_case_id,
                                                   application_form: self,
                                                   status: :completed).exists?
    return status unless task_complete

    CertificationCase.find(certification_case_id).exemption_request_approval_status
  end

  def self.has_pending_form(certification_case_id)
    ExemptionApplicationForm.where(certification_case_id:, status: :in_progress).exists? ||
    ReviewExemptionClaimTask.where(application_form: ExemptionApplicationForm.where(certification_case_id:).all,
                                   status: :pending).exists?
  end

  private

  def case_not_closed
    certification_case = CertificationCase.find_by(id: certification_case_id)
    if certification_case.closed?
      errors.add(:certification_case_id, "has closed")
    elsif certification_case.verification_window_end_date && certification_case.verification_window_end_date < Time.now
      errors.add(:certification_case_id, "verification window has ended")
    end
  end

  def no_pending_forms
    errors.add(:certification_case_id, "has already been taken") if ExemptionApplicationForm.has_pending_form(certification_case_id)
  end
end
