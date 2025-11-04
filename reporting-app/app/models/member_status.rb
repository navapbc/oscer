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
  include Strata::Attributes

  strata_attribute :status, :string
  strata_attribute :determination_method, :string
  strata_attribute :reason_codes, :string, array: true

  validates :status, presence: true,
                     inclusion: { in: %w[compliant exempt not_compliant pending_review awaiting_report] }
end
