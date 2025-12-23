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

  scope :by_region, ->(region) {
    cases = arel_table
    certs = Certification.arel_table

    joins(
      cases.join(certs, Arel::Nodes::InnerJoin)
        .on(cases[:certification_id].eq(certs[:id]))
        .join_sources
    ).merge(Certification.by_region(region))
  }

  def accept_activity_report
    self.activity_report_approval_status = "approved"
    self.activity_report_approval_status_updated_at = Time.current
    save!

    Strata::EventManager.publish("ActivityReportApproved", { case_id: id })
  end

  def deny_activity_report
    self.activity_report_approval_status = "denied"
    self.activity_report_approval_status_updated_at = Time.current
    save!

    Strata::EventManager.publish("ActivityReportDenied", { case_id: id })
  end

  def accept_exemption_request
    transaction do
      self.exemption_request_approval_status = "approved"
      self.exemption_request_approval_status_updated_at = Time.current
      close!

      certification = Certification.find(certification_id)
      certification.record_determination!(
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING[:exemption_request_compliant] ],
        outcome: :exempt,
        determined_at: certification.certification_requirements.certification_date,
        determination_data: {
          exemption_type: "placeholder"
        } # TODO: add determined_by_id
      )
    end

    Strata::EventManager.publish("DeterminedExempt", { case_id: id })
  end

  def deny_exemption_request
    self.exemption_request_approval_status = "denied"
    self.exemption_request_approval_status_updated_at = Time.current
    save!

    Strata::EventManager.publish("DeterminedNotExempt", { case_id: id })
  end

  # Called by ExemptionDeterminationService to record exemption determination
  # Model only handles state changes - service handles events
  # @param eligibility_fact [Strata::RulesEngine::Fact] the evaluation result
  def record_exemption_determination(eligibility_fact)
    certification = Certification.find(certification_id)

    transaction do
      self.exemption_request_approval_status = "approved"
      self.exemption_request_approval_status_updated_at = Time.current
      close!

      certification.record_determination!(
        decision_method: :automated,
        reasons: Determination.to_reason_codes(eligibility_fact),
        outcome: :exempt,
        determination_data: eligibility_fact.reasons.to_json,
        determined_at: certification.certification_requirements.certification_date
      )
    end
  end

  # Called by HoursComplianceDeterminationService to record compliance determination
  # Model only handles state changes - service handles events and notifications
  # @param outcome [Symbol] :compliant or :not_compliant
  # @param hours_data [Hash] aggregated hours data
  def record_hours_compliance(outcome, hours_data)
    certification = Certification.find(certification_id)
    reason_code = outcome == :compliant ? :hours_reported_compliant : :hours_reported_insufficient

    transaction do
      close! if outcome == :compliant

      certification.record_determination!(
        decision_method: :automated,
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        outcome: outcome,
        determination_data: build_hours_determination_data(hours_data),
        determined_at: certification.certification_requirements.certification_date
      )
    end
  end

  def member_status
    MemberStatusService.determine(self).status
  end

  private

  def build_hours_determination_data(hours_data)
    {
      calculation_type: "hours_based",
      total_hours: hours_data[:total_hours],
      target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
      hours_by_category: hours_data[:hours_by_category],
      hours_by_source: hours_data[:hours_by_source],
      ex_parte_activity_ids: hours_data[:ex_parte_activity_ids],
      activity_ids: hours_data[:activity_ids],
      calculated_at: Time.current.iso8601
    }
  end
end
