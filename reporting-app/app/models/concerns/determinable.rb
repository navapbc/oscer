# frozen_string_literal: true

# Determinable enables determination recording on your aggregate roots.
#
# By default, Strata::Determinable provides:
# - A +has_many :determinations+ association (polymorphic)
# - The +record_determination!+ method for recording determinations
#
# Include this concern in your domain models (aggregate roots) to enable determination support.
# ApplicationForm includes Determinable by default.
#
# @example Include in a custom model (e.g., SomethingOtherThanApplicationForm)
#   class SomethingOtherThanApplicationForm < ApplicationRecord
#     include Determinable
#   end
#
# @example Record an automated determination
#   record.record_determination!(
#     decision_method: :automated,
#     reasons: ["pregnant_member"],
#     outcome: :automated_exemption,
#     determination_data: rules_engine.evaluate(:pregnant_member).reasons,
#     determined_at: Time.current
#   )
#
# @example Record a staff-reviewed determination
#   record.record_determination!(
#     decision_method: :staff_review,
#     reasons: ["requirements_verification"],
#     outcome: :requirements_met,
#     determination_data: {verified_fields: [:income, :address]},
#     determined_at: Time.current,
#     determined_by_id: staff_user.id
#   )
#
# @example Query determinations on a subject
#   record = SomethingOtherThanApplicationForm.find(id)
#   record.determinations.latest_first     # Get all, newest first
#   record.determinations.with_outcome(:approved)  # Filter by outcome
#   record.determinations.determined_between(start_date, end_date)  # Filter by time window
#
# @see Strata::Determinable for the method signature
# @see Determination for extending determination behavior with enums and validations
#
module Determinable
  extend ActiveSupport::Concern
  include Strata::Determinable

  # Add custom validations, callbacks, or scopes for determinations here
  def record_determination!(decision_method:, reasons:, outcome:, determination_data:, determined_at:, actor: nil)
    determined_by_id = actor.is_a?(User) ? actor.id : nil
    determination = super(
      decision_method:,
      reasons:,
      outcome:,
      determination_data:,
      determined_at:,
      determined_by_id:
    )

    determination_method = reasons.any? { |reason| reason.include?("exempt") } ? :exemption : :activity_report
    determination_status = outcome == "not_compliant" ? :denied : :approved
    Strata::AuditLog.write!(
      action: "case.#{determination_method}.#{determination_status}",
      actor:,
      subject: self,
      data: { determination_id: determination.id }
    )
    determination
  end
end
