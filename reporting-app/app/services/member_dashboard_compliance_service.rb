# frozen_string_literal: true

# Builds the read-side dashboard projection for OSCER-409 (+MemberDashboardCompliance+).
#
# Pattern parallel to +MemberStatusService+ → +MemberStatus+: this service does the eager
# work (hours aggregation, report-status token, exemption flow state) and hands back a
# +MemberDashboardCompliance+ value object. The value object holds AR refs so its
# income-side and exemption-history readers can run their queries lazily on first access.
class MemberDashboardComplianceService
  class << self
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil]
    # @param exemption_application_form [ExemptionApplicationForm, nil]
    # @param member_status [MemberStatus]
    # @return [MemberDashboardCompliance]
    def build(certification:, certification_case:, exemption_application_form:, member_status:)
      latest = member_status.latest_determination
      lookback = certification.certification_requirements.continuous_lookback_period
      show_income = income_summary_visible?(latest, member_status) && lookback.present?

      external_hourly_rel = lookback.present? ? aggregator.fetch_external_hourly_activities(certification) : ExternalHourlyActivity.none
      # Pass only the external relation: +HoursComplianceDeterminationService+ will fetch and
      # +.reorder(nil)+ member rows internally so its +GROUP BY :category+ aggregation hits
      # the Postgres SUM path instead of erroring on the +ORDER BY+ on +member_hour_activities_for_certification+.
      hours_summary = HoursComplianceDeterminationService.aggregate_hours_for_certification(
        certification,
        certification_case: certification_case,
        external_hourly_activities: external_hourly_rel
      )

      target_hours = HoursComplianceDeterminationService::TARGET_HOURS
      # +Numeric#round+ to the nearest integer (not +.to_i+, which truncates toward zero), e.g.
      # 79.5 → 80 — keeps display parity with the staff side.
      total_hours = hours_summary[:total_hours].to_f.round

      MemberDashboardCompliance.new(
        certification: certification,
        certification_case: certification_case,
        exemption_application_form: exemption_application_form,
        lookback: lookback,
        report_status_token: member_status.dashboard_report_status,
        latest_determination: latest,
        show_income_summary: show_income,
        total_hours_reported: total_hours,
        target_hours: target_hours,
        hours_needed: [ target_hours - total_hours, 0 ].max,
        certification_date: certification.certification_requirements.certification_date,
        due_date: certification.certification_requirements.due_date,
        hours_summary: hours_summary,
        exemption_flow_state: exemption_flow_state(
          exemption_application_form: exemption_application_form,
          certification_case: certification_case,
          member_status: member_status
        )
      )
    end

    # Public class API for callers that only need the deterministic case tie-break (e.g.
    # +DashboardController#set_certification_case+) without including +ActivityAggregator+.
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil]
    # @return [CertificationCase, nil]
    def case_for_certification(certification, certification_case = nil)
      aggregator.certification_case_for_certification(certification, certification_case)
    end

    private

    # Singleton holder for +ActivityAggregator+ instance methods, scoped private so
    # +ActivityAggregator+'s 8 public methods do not become public class methods on
    # this service.
    def aggregator
      @aggregator ||= Object.new.extend(ActivityAggregator)
    end

    # Returns true when the dashboard should surface income summary cards.
    #
    # @note A +nil+ +ce_calculation_type+ (no determination yet) defaults to +true+:
    #   the pre-determination state assumes income reporting until product confirms an
    #   alternate intake. If product narrows this rule (e.g. "no determination ⇒ hide
    #   income"), update both this method and the
    #   +"when latest determination is hours_based"+ / +"when member status is exempt"+
    #   specs at +spec/services/member_dashboard_compliance_service_spec.rb+.
    def income_summary_visible?(latest_determination, member_status)
      return false if member_status.status == MemberStatus::EXEMPT

      ct = latest_determination&.ce_calculation_type
      return false if ct == Determination::CALCULATION_TYPE_HOURS_BASED

      ct.nil? ||
        ct == Determination::CALCULATION_TYPE_INCOME_BASED ||
        ct == Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED
    end

    def exemption_flow_state(exemption_application_form:, certification_case:, member_status:)
      return MemberDashboardCompliance::EXEMPTION_APPROVED if member_status.status == MemberStatus::EXEMPT

      return MemberDashboardCompliance::EXEMPTION_NOT_STARTED if exemption_application_form.blank?

      if !exemption_application_form.submitted?
        return MemberDashboardCompliance::EXEMPTION_DRAFT
      end

      if certification_case&.exemption_request_approval_status == "approved"
        return MemberDashboardCompliance::EXEMPTION_APPROVED
      end

      if certification_case&.exemption_request_approval_status == "denied"
        return MemberDashboardCompliance::EXEMPTION_DENIED
      end

      # Submitted, no staff decision yet
      MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
    end
  end
end
