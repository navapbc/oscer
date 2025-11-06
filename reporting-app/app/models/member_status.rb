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
# @example Get member status
#   status = MemberStatusService.determine(certification)
#   status.status # => "compliant"
#   status.determination_method # => "automated"
#   status.reason_codes # => ["age_under_19_exempt"]
class MemberStatus < Strata::ValueObject
  AWAITING_REPORT = "awaiting_report"
  EXEMPT = "exempt"
  COMPLIANT = "compliant"
  NOT_COMPLIANT = "not_compliant"
  PENDING_REVIEW = "pending_review"

  include Strata::Attributes

  strata_attribute :status, :string
  strata_attribute :determination_method, :string
  strata_attribute :reason_codes, :string, array: true
  strata_attribute :human_readable_reason_codes, :string, array: true

  validates :status, presence: true,
                     inclusion: { in: [ AWAITING_REPORT, EXEMPT, COMPLIANT, NOT_COMPLIANT, PENDING_REVIEW ] }
end
