# frozen_string_literal: true

class CertificationCase < Strata::Case
  # The following attributes are inherited from Strata::Case
  # attribute :certification_id, :uuid
  # attribute :status, :integer
  # enum :status, open: 0, closed: 1
  # attribute :business_process_current_step, :string
  # attribute :facts, :jsonb

  # Don't add an ActiveRecord association since Certification
  # is a separate aggregate root and we don't want to add
  # dependencies between the aggregates at the database layer
  attr_accessor :certification

  store_accessor :facts, :activity_report_approval_status, :activity_report_approval_status_updated_at,
    :exemption_request_approval_status, :exemption_request_approval_status_updated_at

  # Member certification status values
  MEMBER_STATUS = {
    awaiting_report: "awaiting_report",
    pending_review: "pending_review",
    exempt: "exempt",
    met_requirements: "met_requirements",
    not_met_requirements: "not_met_requirements"
  }.freeze

  def accept_activity_report
    transaction do
      self.activity_report_approval_status = "approved"
      self.activity_report_approval_status_updated_at = Time.current
      save!
      close!
    end

    Strata::EventManager.publish("DeterminedRequirementsMet", { case_id: id })
  end

  def deny_activity_report
    transaction do
      self.activity_report_approval_status = "denied"
      self.activity_report_approval_status_updated_at = Time.current
      save!
      close!
    end

    Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: id })
  end

  def accept_exemption_request
    transaction do
      self.exemption_request_approval_status = "approved"
      self.exemption_request_approval_status_updated_at = Time.current
      save!
      close!
    end

    Strata::EventManager.publish("DeterminedExempt", { case_id: id })
  end

  def deny_exemption_request
    self.exemption_request_approval_status = "denied"
    self.exemption_request_approval_status_updated_at = Time.current
    save!

    Strata::EventManager.publish("DeterminedNotExempt", { case_id: id })
  end

  # Determines the member's certification status based on business process state
  # Uses the workflow's current_step as the source of truth
  def member_status
    case business_process_instance.current_step
    when "report_activities"
      MEMBER_STATUS[:awaiting_report]
    when "review_activity_report", "review_exemption_claim"
      MEMBER_STATUS[:pending_review]
    when "end"
      return MEMBER_STATUS[:exempt] if exemption_request_approval_status == "approved"
      return MEMBER_STATUS[:met_requirements] if activity_report_approval_status == "approved"
      MEMBER_STATUS[:not_met_requirements]
    else
      # System process steps (exemption_check, ex_parte_determination) default to awaiting
      MEMBER_STATUS[:awaiting_report]
    end
  end
end
