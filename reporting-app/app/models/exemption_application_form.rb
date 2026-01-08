# frozen_string_literal: true

class ExemptionApplicationForm < Strata::ApplicationForm
  # TODO: Remove when revising the old exemption screener flow
  LEGACY_EXEMPTION_TYPES = %w[short_term_hardship incarceration].freeze

  enum :exemption_type, Exemption.enum_hash
  validates :exemption_type, inclusion: { in: Exemption.types + LEGACY_EXEMPTION_TYPES }, allow_nil: true
  validates :certification_case_id, uniqueness: true

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
end
