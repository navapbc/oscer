# frozen_string_literal: true

# Determination wraps Strata::Determination for your application.
#
# By default, Strata::Determination provides:
# - A polymorphic +subject+ association to any aggregate root
# - Validations for all required fields (+decision_method+, +reasons+, +outcome+, +determination_data+, +determined_at+)
# - Query scopes for filtering by subject, decision method, reasons, outcome, user, and time windows
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
#     validates :reasons, presence: true, inclusion: { in: %w(pregnant_member incarcerated other) }
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
  REASON_CODE_MAPPING = {
    age_under_19: "age_under_19_exempt",
    age_over_65: "age_over_65_exempt",
    is_pregnant: "pregnancy_exempt",
    is_american_indian_or_alaska_native: "american_indian_alaska_native_exempt",
    income_reported_compliant: "income_reported_compliant",
    hours_reported_compliant: "hours_reported_compliant",
    exemption_request_compliant: "exemption_request_compliant",
    hours_insufficient: "hours_insufficient"
  }.freeze

  VALID_REASONS = REASON_CODE_MAPPING.values.freeze

  enum :decision_method, { automated: "automated", manual: "manual" }
  enum :outcome, { compliant: "compliant", exempt: "exempt", not_compliant: "not_compliant" }

  validates :reasons, presence: true, inclusion: { in: VALID_REASONS }

  default_scope { order(created_at: :desc) }

  # Batch query scopes
  scope :for_certifications, ->(certification_ids) {
    where(subject_type: "Certification", subject_id: certification_ids)
  }

  scope :latest_per_subject, -> {
    # Override default_scope ordering for DISTINCT ON to work correctly
    unscope(:order)
      .select("DISTINCT ON (subject_id) strata_determinations.*")
      .order("subject_id, created_at DESC")
  }

  def self.to_reason_codes(eligibility_fact)
    eligibility_fact_reasons = eligibility_fact.reasons.select { |reason| reason.value }.map(&:name).map(&:to_sym)
    eligibility_fact_reasons.map { |reason| REASON_CODE_MAPPING[reason] }
  end
end
