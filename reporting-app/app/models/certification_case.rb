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

  def accept_activity_report
    transaction do
      self.activity_report_approval_status = "approved"
      self.activity_report_approval_status_updated_at = Time.current
      close!

      certification = Certification.find(self.certification_id)
      certification.record_determination!(
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING[:hours_reported_compliant] ], # TODO: lookup activity type to determine reason code
        outcome: :compliant,
        determined_at: certification.certification_requirements.certification_date,
        determination_data: {
          activity_type: "placeholder",
          activity_hours: 0,
          income: 0
        } # TODO: add determined_by_id
      )
    end

    Strata::EventManager.publish("DeterminedRequirementsMet", { case_id: id })
  end

  def deny_activity_report
    self.activity_report_approval_status = "denied"
    self.activity_report_approval_status_updated_at = Time.current
    close!

    Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: id })
  end

  def accept_exemption_request
    transaction do
      self.exemption_request_approval_status = "approved"
      self.exemption_request_approval_status_updated_at = Time.current
      close!

      certification = Certification.find(self.certification_id)
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

  def determine_ex_parte_exemption(eligibility_fact)
    certification = Certification.find(self.certification_id)

    if eligibility_fact.value
      transaction do
        self.exemption_request_approval_status = "approved"
        self.exemption_request_approval_status_updated_at = Time.current
        self.close!

        certification.record_determination!(
          decision_method: :automated,
          reasons: Determination.to_reason_codes(eligibility_fact),
          outcome: :exempt,
          determination_data: eligibility_fact.reasons.to_json,
          determined_at: certification.certification_requirements.certification_date
        )
      end

      Strata::EventManager.publish("DeterminedExempt", { case_id: id })

      # Send exempt notification email
      NotificationService.send_email_notification(
        MemberMailer,
        { certification: certification },
        :exempt_email,
        [ certification.member_email ]
      )
    else
      Strata::EventManager.publish("DeterminedNotExempt", { case_id: id })

      # TODO: move action required email to after exparte determination step is complete
      # once it has been implemented
      # Send action required notification email
      NotificationService.send_email_notification(
        MemberMailer,
        { certification: certification },
        :action_required_email,
        [ certification.member_email ]
      )
    end
  end

  # Called by HoursComplianceDeterminationService at EX_PARTE_CE_CHECK step
  # @param outcome [Symbol] :compliant or :not_compliant
  # @param hours_data [Hash] aggregated hours data
  def determine_ce_hours_compliance(outcome, hours_data)
    certification = Certification.find(self.certification_id)

    if outcome == :compliant
      transaction do
        self.activity_report_approval_status = "approved"
        self.activity_report_approval_status_updated_at = Time.current
        close!

        certification.record_determination!(
          decision_method: :automated,
          reasons: [ Determination::REASON_CODE_MAPPING[:hours_reported_compliant] ],
          outcome: :compliant,
          determination_data: build_hours_determination_data(hours_data),
          determined_at: certification.certification_requirements.certification_date
        )
      end

      Strata::EventManager.publish("DeterminedRequirementsMet", { case_id: id })
    else
      Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: id })
    end
  end

  private

  def build_hours_determination_data(hours_data)
    {
      calculation_type: "hours_based",
      calculation_method: "business_process",
      total_hours: hours_data[:total_hours],
      target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
      hours_by_category: hours_data[:hours_by_category],
      hours_by_source: hours_data[:hours_by_source],
      ex_parte_activity_ids: hours_data[:ex_parte_activity_ids],
      activity_ids: hours_data[:activity_ids],
      calculated_at: Time.current.iso8601
    }
  end

  def member_status
    MemberStatusService.determine(self).status
  end
end
