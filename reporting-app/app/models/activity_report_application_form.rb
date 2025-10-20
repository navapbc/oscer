# frozen_string_literal: true

class ActivityReportApplicationForm < Strata::ApplicationForm
  belongs_to :certification, optional: true
  has_many :activities, strict_loading: true, autosave: true, dependent: :destroy

  strata_attribute :reporting_periods, :year_month, array: true

  def activities_by_id
    @activities_by_id ||= activities.index_by(&:id)
  end

  def activities_by_month
    @activities_by_month ||= activities.group_by(&:month)
  end

  default_scope { includes(:activities, :certification) }

  accepts_nested_attributes_for :activities, allow_destroy: true

  def self.find_by_certification_case_id(certification_case_id)
    find_by(certification_case_id:)
  end

  # Include the case id
  def event_payload
    super.merge(case_id: certification_case_id)
  end

  def self.information_request_class
    ActivityReportInformationRequest
  end
end
