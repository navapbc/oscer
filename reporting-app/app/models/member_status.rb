# frozen_string_literal: true

# Represents the certification status of a member.
# Returns the current status, determination method, and reason codes if applicable.
#
# Possible status values:
# - "compliant" - Member has met certification requirements through activity report
# - "exempt" - Member is exempt from certification requirements
# - "not_compliant" - Member has not met certification requirements
# - "pending_review" - Submitted form awaiting staff review
# - "awaiting_report" - Member has not yet submitted required forms
#
# == +latest_determination+ is an out-of-band accessor
#
# +latest_determination+ holds the +Determination+ record that produced this status, when one
# exists (set by +MemberStatusService#status_from_determination+; +nil+ for case-step fallbacks).
# It is intentionally **not** a +strata_attribute+ and therefore:
# - is excluded from +#attributes+
# - is excluded from +#blank?+ (which inspects +attributes.values+)
# - is excluded from +Strata::ValueObject#==+ (which compares +attributes+ only — two
#   +MemberStatus+ instances with the same status fields but different
#   +latest_determination+ records still compare equal)
# - is excluded from JSON serialization via +ActiveModel::Serializers::JSON+
#
# Callers comparing two +MemberStatus+ instances or serializing one should not assume the
# determination is part of that contract.
#
# @example Get member status
#   status = MemberStatusService.determine(certification)
#   status.status # => "compliant"
#   status.determination_method # => "automated"
#   status.reason_codes # => ["age_under_19_excluded"]
#   status.latest_determination # => <Determination ...> or nil
class MemberStatus < Strata::ValueObject
  # Stable tokens for member dashboard / OSCER-480 (display copy is client-side i18n).
  DASHBOARD_REPORT_IN_PROGRESS = "in_progress"
  DASHBOARD_REPORT_UNDER_REVIEW = "under_review"
  DASHBOARD_REPORT_COMPLIANT = "compliant"
  DASHBOARD_REPORT_NOT_COMPLIANT = "not_compliant"
  DASHBOARD_REPORT_EXEMPT = "exempt"

  AWAITING_REPORT = "awaiting_report"
  EXEMPT = "exempt"
  EXCEPTED = "excepted"
  COMPLIANT = "compliant"
  NOT_COMPLIANT = "not_compliant"
  PENDING_REVIEW = "pending_review"

  # Outcomes that mean a certification period is finished (used for "previous completed" dashboard UI).
  TERMINAL_CERTIFICATION_STATUSES = [ COMPLIANT, EXEMPT, NOT_COMPLIANT ].freeze

  include Strata::Attributes

  strata_attribute :status, :string
  strata_attribute :determination_method, :string
  strata_attribute :reason_codes, :string, array: true
  strata_attribute :human_readable_reason_codes, :string, array: true

  # Plain accessor, not a +strata_attribute+: +Strata::ValueObject+'s +ActiveModel::Attributes+
  # backing only handles primitive types, and we don't want a +Determination+ record to factor
  # into +#blank?+ (which inspects +attributes.values+). Set by
  # +MemberStatusService#status_from_determination+; nil when status was derived from the case step.
  attr_accessor :latest_determination

  validates :status, presence: true,
                     inclusion: { in: [ AWAITING_REPORT, EXCEPTED, EXEMPT, COMPLIANT, NOT_COMPLIANT, PENDING_REVIEW ] }

  # Maps domain +status+ to dashboard report-state tokens (OSCER-409 / #480).
  # @return [String]
  def dashboard_report_status
    case status
    when AWAITING_REPORT then DASHBOARD_REPORT_IN_PROGRESS
    when PENDING_REVIEW then DASHBOARD_REPORT_UNDER_REVIEW
    when COMPLIANT then DASHBOARD_REPORT_COMPLIANT
    when NOT_COMPLIANT then DASHBOARD_REPORT_NOT_COMPLIANT
    when EXEMPT then DASHBOARD_REPORT_EXEMPT
    when EXCEPTED then DASHBOARD_REPORT_EXEMPT
    else DASHBOARD_REPORT_IN_PROGRESS
    end
  end

  # @return [Boolean] true when the member's certification period has a final outcome
  def certification_period_completed?
    status.in?(TERMINAL_CERTIFICATION_STATUSES)
  end
end
