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

  # Latest open case for a member (by certification created_at). Used when persisting new
  # Income rows to run income compliance recalculation for the active certification.
  # @param member_id [String]
  # @return [UUID, nil] certification_id
  def self.open_certification_id_for_member(member_id)
    joins("INNER JOIN certifications ON certifications.id = certification_cases.certification_id")
      .where(certifications: { member_id: member_id })
      .open
      .order("certifications.created_at DESC")
      .limit(1)
      .pick(:certification_id)
  end

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

  # Called by HoursComplianceDeterminationService (+#calculate+, etc.) to persist hours-based CE.
  # Model only handles state changes; services own events/notifications.
  # Uses +record_automated_ce_compliance+ with default +close_on_compliant: true+ — when +outcome+ is
  # +:compliant+, the case is +close!+d in the same transaction as the determination (open-case queues
  # drop the case). Income silent recalculation is aligned via +record_income_compliance+.
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

  # Called by IncomeComplianceDeterminationService#calculate (e.g. after +IncomeService+ persists new
  # income for an open case) to record income-only CE (+CALCULATION_TYPE_INCOME_BASED+; not used by the
  # combined ex parte CE business process step).
  #
  # Default +close_on_compliant: true+ matches +record_hours_compliance+: compliant outcomes +close!+
  # the case so behavior matches hours silent recalculation and the case leaves open caseworker queues.
  # Pass +close_on_compliant: false+ if product later wants an automated determination row without closing.
  #
  # @param outcome [Symbol] :compliant or :not_compliant
  # @param income_data [Hash] aggregated income data from IncomeComplianceDeterminationService
  # @param close_on_compliant [Boolean] see above; default +true+
  def record_income_compliance(outcome, income_data, close_on_compliant: true)
    record_automated_ce_compliance(
      outcome,
      build_income_determination_data(income_data),
      compliant_reason: :income_reported_compliant,
      not_compliant_reason: :income_reported_insufficient,
      close_on_compliant: close_on_compliant
    )
  end

  # Ex parte CE check: one automated determination with both tracks in +determination_data+.
  # Member is compliant if either +hours_ok+ or +income_ok+; not compliant only when both are false.
  # Events/notifications are published by CommunityEngagementCheckService (via Strata).
  #
  # @param certification [Certification] aggregate root for +record_determination!+
  # @param hours_data [Hash] from HoursComplianceDeterminationService.aggregate_hours_for_certification
  # @param income_data [Hash] from IncomeComplianceDeterminationService.aggregate_income_for_certification
  # @param hours_ok [Boolean]
  # @param income_ok [Boolean]
  def record_ex_parte_ce_combined_assessment(certification:, hours_data:, income_data:, hours_ok:, income_ok:)
    outcome = (hours_ok || income_ok) ? :compliant : :not_compliant
    reasons = ex_parte_ce_combined_reason_codes(outcome: outcome, hours_ok: hours_ok, income_ok: income_ok)
    determination_data = build_ex_parte_ce_combined_determination_data(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: hours_ok,
      income_ok: income_ok
    )

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
  # @param close_on_compliant [Boolean] when +true+ (default), +:compliant+ outcomes call +close!+ before
  # persisting the determination. When +false+, the determination is still written but the case stays open
  # (+record_income_compliance+ may pass +false+; +record_hours_compliance+ always uses the default).
  def record_automated_ce_compliance(outcome, determination_data, compliant_reason:, not_compliant_reason:,
                                     close_on_compliant: true)
    certification = Certification.find(certification_id)
    reason_code = outcome == :compliant ? compliant_reason : not_compliant_reason

    transaction do
      close! if close_on_compliant && outcome == :compliant

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
      Determination::SATISFIED_BY_BOTH
    elsif hours_ok
      Determination::SATISFIED_BY_HOURS
    elsif income_ok
      Determination::SATISFIED_BY_INCOME
    else
      Determination::SATISFIED_BY_NEITHER
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
