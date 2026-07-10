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
# Determination rows store arbitrary JSON in +determination_data+. For **automated CE**
# (hours, income, and combined hours + income CE), the canonical serialized contract is defined by
# {Determinations::HoursBasedDeterminationData}, {Determinations::IncomeBasedDeterminationData},
# and {Determinations::ExternalCECombinedDeterminationData} — those classes validate and emit the
# payloads written by {CertificationCase}. Other flows (manual activity report, exemption
# placeholder, automated eligibility JSON) use different shapes and are not covered by those VOs.
#
# ## Legacy and non-CE +determination_data+
#
# Existing production rows may predate this contract or use ad-hoc keys (for example exemption
# placeholders or +Strata::RulesEngine+ fact JSON). The app does **not** coerce or re-validate those
# on read. Consumers should treat unknown +calculation_type+ or missing keys defensively. Older
# combined external CE rows may still store +calculation_type+ as
# +Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED_LEGACY+ (+ex_parte_ce_combined+); new writes use
# +CALCULATION_TYPE_EXTERNAL_CE_COMBINED+. A future backfill or strict read path can be ticketed
# separately if product needs normalized history.
class Determination < Strata::Determination
  # Stored in +determination_data+ JSON for CE compliance automated calculations.
  CALCULATION_TYPE_HOURS_BASED = "hours_based"
  CALCULATION_TYPE_INCOME_BASED = "income_based"
  # External CE step: one determination with both hours and income assessments (OR compliant).
  CALCULATION_TYPE_EXTERNAL_CE_COMBINED = "external_ce_combined"
  # Historical +determination_data["calculation_type"]+ before +external_ce_combined+; use for BI/read filters on old rows.
  CALCULATION_TYPE_EXTERNAL_CE_COMBINED_LEGACY = "ex_parte_ce_combined"
  # Stored in +determination_data["satisfied_by"]+ when +calculation_type+ is +CALCULATION_TYPE_EXTERNAL_CE_COMBINED+ (or legacy).
  SATISFIED_BY_BOTH = "both"
  SATISFIED_BY_HOURS = "hours"
  SATISFIED_BY_INCOME = "income"
  SATISFIED_BY_NEITHER = "neither"
  CALCULATION_METHOD_AUTOMATED_INCOME_INTAKE = "automated_income_intake"

  REASON_CODE_MAPPING = {
    age_under_19: "age_under_19_excluded",
    age_over_65: "age_over_65_excluded",
    is_pregnant: "pregnancy_excluded",
    is_american_indian_or_alaska_native: "american_indian_alaska_native_excluded",
    income_reported_compliant: "income_reported_compliant",
    income_reported_insufficient: "income_reported_insufficient",
    hours_reported_compliant: "hours_reported_compliant",
    hours_reported_insufficient: "hours_reported_insufficient",
    exemption_request_compliant: "exemption_request_compliant",
    is_veteran_with_disability: "veteran_disability_excluded",
    denial_response_convincing: "denial_response_convincing",
    denial_response_not_convincing: "denial_response_not_convincing",
    # External-exception reason codes (see ExceptionDeterminationService). "Excepted" is a
    # distinct outcome from "excluded"/"exempt" — do not conflate the three.
    age_was_under_19: "age_under_19_excepted",
    receiving_inpatient_medical_care: "inpatient_medical_care_excepted",
    resides_in_declared_emergency_county: "declared_emergency_county_excepted",
    resides_in_high_unemployment_county: "high_unemployment_county_excepted",
    traveling_for_medical_care: "medical_travel_excepted",
    participating_in_other_program: "other_program_excepted"
  }.freeze

  # Reasons recorded when a staff reviewer approves or denies a member's denial response.
  DENIAL_RESPONSE_REASONS = REASON_CODE_MAPPING.values_at(
    :denial_response_convincing,
    :denial_response_not_convincing
  ).freeze

  EXEMPTION_REASONS = REASON_CODE_MAPPING.values_at(
    :age_under_19,
    :age_over_65,
    :is_pregnant,
    :is_american_indian_or_alaska_native,
    :exemption_request_compliant,
    :is_veteran_with_disability
  ).freeze

  VALID_REASONS = REASON_CODE_MAPPING.values.freeze

  enum :decision_method, { automated: "automated", manual: "manual" }
  enum :outcome, { compliant: "compliant", exempt: "exempt", excluded: "excluded", excepted: "excepted", not_compliant: "not_compliant" }

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

  # CE automated/manual payload uses +determination_data["calculation_type"]+ with string keys from JSON.
  # @return [String, nil] e.g. +CALCULATION_TYPE_INCOME_BASED+, +CALCULATION_TYPE_HOURS_BASED+, +CALCULATION_TYPE_EXTERNAL_CE_COMBINED+
  def ce_calculation_type
    return nil if determination_data.blank?

    determination_data.stringify_keys["calculation_type"].presence
  end
end
