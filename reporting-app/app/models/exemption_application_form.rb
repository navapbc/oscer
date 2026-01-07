# frozen_string_literal: true

class ExemptionApplicationForm < Strata::ApplicationForm
  enum :exemption_type, ExemptionTypeConfig.enum_hash
  validates :exemption_type, inclusion: { in: ExemptionTypeConfig.valid_values }, allow_nil: true
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
