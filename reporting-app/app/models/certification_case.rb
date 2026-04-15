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
    certification = Certification.find(certification_id)
    hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)

    transaction do
      self.activity_report_approval_status = "approved"
      self.activity_report_approval_status_updated_at = Time.current
      close!

      certification.record_determination!(
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING[:hours_reported_compliant] ],
        outcome: :compliant,
        determination_data: build_hours_determination_data(hours_data),
        determined_at: certification.certification_requirements.certification_date
      )
    end

    Strata::EventManager.publish("ActivityReportApproved", { case_id: id, certification_id: certification_id })
  end

  def deny_activity_report
    certification = Certification.find(certification_id)
    hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)

    transaction do
      self.activity_report_approval_status = "denied"
      self.activity_report_approval_status_updated_at = Time.current
      close!

      certification.record_determination!(
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING[:hours_reported_insufficient] ],
        outcome: :not_compliant,
        determination_data: build_hours_determination_data(hours_data),
        determined_at: certification.certification_requirements.certification_date
      )
    end

    Strata::EventManager.publish("ActivityReportDenied", { case_id: id, certification_id: certification_id })
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

    Strata::EventManager.publish("DeterminedExempt", { case_id: id, certification_id: certification_id })
  end

  def deny_exemption_request
    self.exemption_request_approval_status = "denied"
    self.exemption_request_approval_status_updated_at = Time.current
    save!

    Strata::EventManager.publish("DeterminedNotExempt", { case_id: id, certification_id: certification_id })
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
    record_automated_ce_compliance(
      outcome,
      build_hours_determination_data(hours_data),
      compliant_reason: :hours_reported_compliant,
      not_compliant_reason: :hours_reported_insufficient
    )
  end

  # Called by IncomeComplianceDeterminationService to record income-based CE determination.
  # Model only handles state changes — service handles events and notifications.
  # @param outcome [Symbol] :compliant or :not_compliant
  # @param income_data [Hash] aggregated income data from IncomeComplianceDeterminationService
  def record_income_compliance(outcome, income_data)
    record_automated_ce_compliance(
      outcome,
      build_income_determination_data(income_data),
      compliant_reason: :income_reported_compliant,
      not_compliant_reason: :income_reported_insufficient
    )
  end

  # Ex parte CE check: one automated determination with both tracks in +determination_data+.
  # Member is compliant if either +hours_ok+ or +income_ok+; not compliant only when both are false.
  # Events/notifications are published by CertificationBusinessProcess.
  #
  # @param hours_data [Hash] from HoursComplianceDeterminationService.aggregate_hours_for_certification
  # @param income_data [Hash] from IncomeComplianceDeterminationService.aggregate_income_for_certification
  # @param hours_ok [Boolean]
  # @param income_ok [Boolean]
  def record_ex_parte_ce_combined_assessment(hours_data:, income_data:, hours_ok:, income_ok:)
    outcome = (hours_ok || income_ok) ? :compliant : :not_compliant
    reasons = ex_parte_ce_combined_reason_codes(outcome: outcome, hours_ok: hours_ok, income_ok: income_ok)
    determination_data = build_ex_parte_ce_combined_determination_data(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: hours_ok,
      income_ok: income_ok
    )

    certification = Certification.find(certification_id)
    transaction do
      close! if outcome == :compliant

      certification.record_determination!(
        decision_method: :automated,
        reasons: reasons,
        outcome: outcome,
        determination_data: determination_data,
        determined_at: certification.certification_requirements.certification_date
      )
    end
  end

  def member_status
    MemberStatusService.determine(self).status
  end

  private

  # @param outcome [Symbol] :compliant or :not_compliant
  # @param determination_data [Hash] payload for +record_determination!+
  # @param compliant_reason [Symbol] key into +Determination::REASON_CODE_MAPPING+ when compliant
  # @param not_compliant_reason [Symbol] key into +Determination::REASON_CODE_MAPPING+ when not compliant
  def record_automated_ce_compliance(outcome, determination_data, compliant_reason:, not_compliant_reason:)
    certification = Certification.find(certification_id)
    reason_code = outcome == :compliant ? compliant_reason : not_compliant_reason

    transaction do
      close! if outcome == :compliant

      certification.record_determination!(
        decision_method: :automated,
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        outcome: outcome,
        determination_data: determination_data,
        determined_at: certification.certification_requirements.certification_date
      )
    end
  end

  def build_hours_determination_data(hours_data)
    {
      calculation_type: Determination::CALCULATION_TYPE_HOURS_BASED,
      total_hours: hours_data[:total_hours],
      target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
      hours_by_category: hours_data[:hours_by_category],
      hours_by_source: hours_data[:hours_by_source],
      ex_parte_activity_ids: hours_data[:ex_parte_activity_ids],
      activity_ids: hours_data[:activity_ids],
      calculated_at: Time.current.iso8601
    }
  end

  def build_income_determination_data(income_data)
    income_by = income_data[:income_by_source]
    period_start = income_data[:period_start]
    period_end = income_data[:period_end]

    {
      calculation_type: Determination::CALCULATION_TYPE_INCOME_BASED,
      total_income: income_data[:total_income].to_f,
      target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_f,
      income_by_source: {
        income: income_by[:income].to_f,
        activity: income_by[:activity].to_f
      },
      period_start: period_start&.respond_to?(:iso8601) ? period_start.iso8601 : period_start&.to_s,
      period_end: period_end&.respond_to?(:iso8601) ? period_end.iso8601 : period_end&.to_s,
      income_ids: income_data[:income_ids],
      calculation_method: Determination::CALCULATION_METHOD_AUTOMATED_INCOME_INTAKE,
      calculated_at: Time.current.iso8601
    }
  end

  def ex_parte_ce_combined_reason_codes(outcome:, hours_ok:, income_ok:)
    if outcome == :compliant
      [].tap do |codes|
        codes << Determination::REASON_CODE_MAPPING[:hours_reported_compliant] if hours_ok
        codes << Determination::REASON_CODE_MAPPING[:income_reported_compliant] if income_ok
      end
    else
      [
        Determination::REASON_CODE_MAPPING[:hours_reported_insufficient],
        Determination::REASON_CODE_MAPPING[:income_reported_insufficient]
      ]
    end
  end

  def build_ex_parte_ce_combined_determination_data(hours_data:, income_data:, hours_ok:, income_ok:)
    satisfied_by = if hours_ok && income_ok
      "both"
    elsif hours_ok
      "hours"
    elsif income_ok
      "income"
    else
      "neither"
    end

    {
      calculation_type: Determination::CALCULATION_TYPE_EX_PARTE_CE_COMBINED,
      satisfied_by: satisfied_by,
      hours: build_hours_determination_data(hours_data).merge(compliant: hours_ok),
      income: build_income_determination_data(income_data).merge(compliant: income_ok),
      calculated_at: Time.current.iso8601
    }
  end
end
