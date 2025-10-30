# frozen_string_literal: true

# Determination wraps Strata::Determination for your application.
#
# By default, Strata::Determination provides:
# - A polymorphic +subject+ association to any aggregate root
# - Validations for all required fields (+decision_method+, +reason+, +outcome+, +determination_data+, +determined_at+)
# - Query scopes for filtering by subject, decision method, reason, outcome, user, and time windows
# - Support for automated, staff-reviewed, and attested determinations
#
# Extend this class to add:
# - Domain-specific enums (e.g., outcome types specific to your business)
# - Custom validations or business rules
# - Custom scopes or query methods
# - Callbacks for side effects
#
# @example Add domain-specific enums and validations
#   class Determination < Strata::Determination
#     enum decision_method: { automated: "automated", staff_review: "staff_review", attestation: "attestation" }
#     enum outcome: { approved: "approved", denied: "denied", pending: "pending" }
#
#     validates :reason, inclusion: { in: %w(pregnant_member incarcerated other) }
#   end
#
# @example Query determinations for a specific subject
#   form = MyApplicationForm.find(id)
#   determinations = form.determinations.with_outcome(:approved)
#   latest = form.determinations.latest_first.first
#
# @see Strata::Determination for available associations, validations, and scopes
# @see Strata::Determinable for the +record_determination!+ method to use in models
#
class Determination < Strata::Determination
  # Add custom enums, validations, scopes, and callbacks here
end
