# frozen_string_literal: true

class ExemptionApplicationForm < Strata::ApplicationForm
  enum :exemption_type, {
    short_term_hardship: "short_term_hardship",
    incarceration: "incarceration"
  }
  validates :exemption_type, inclusion: { in: exemption_types.values }, allow_nil: true

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents }

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
