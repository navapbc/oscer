# frozen_string_literal: true

# Listens to domain events and sends appropriate email notifications.
# This decouples notifications from the business process workflow.
#
# Subscribed events and their notifications:
# - DeterminedExempt → exempt_email
# - DeterminedHoursMet / DeterminedCommunityEngagementMet → compliant_email
# - DeterminedActionRequired / DeterminedCommunityEngagementActionRequired → action_required_email
# - DeterminedHoursInsufficient → insufficient_hours_email
# - DeterminedCommunityEngagementInsufficient → insufficient_community_engagement_email (hours and/or income sections).
#   Payload carries optional +hours_data+ / +income_data+ aggregates; mailer +show_*+ flags are derived in
#   +handle_insufficient_community_engagement+ unless +show_hours_insufficient+ / +show_income_insufficient+
#   are set explicitly (e.g. hours-only mail with +income_data+ omitted or present but hidden).
# - ActivityReportApproved → compliant_email (reviewer determined compliance)
# - ActivityReportDenied → insufficient_hours_email (reviewer determined non-compliance)
class NotificationsEventListener
  class << self
    def subscribe
      Strata::EventManager.subscribe("DeterminedExempt", method(:handle_exempt))
      Strata::EventManager.subscribe("DeterminedHoursMet", method(:handle_compliant))
      Strata::EventManager.subscribe("DeterminedCommunityEngagementMet", method(:handle_compliant))
      Strata::EventManager.subscribe("DeterminedActionRequired", method(:handle_action_required))
      Strata::EventManager.subscribe("DeterminedCommunityEngagementActionRequired", method(:handle_action_required))
      Strata::EventManager.subscribe("DeterminedHoursInsufficient", method(:handle_insufficient_hours))
      Strata::EventManager.subscribe("DeterminedCommunityEngagementInsufficient", method(:handle_insufficient_community_engagement))
      Strata::EventManager.subscribe("ActivityReportApproved", method(:handle_activity_report_approved))
      Strata::EventManager.subscribe("ActivityReportDenied", method(:handle_activity_report_denied))
    end

    private

    def handle_exempt(event)
      certification = fetch_certification(event)
      send_notification(certification, :exempt_email)
    end

    def handle_compliant(event)
      certification = fetch_certification(event)
      send_notification(certification, :compliant_email)
    end

    def handle_action_required(event)
      certification = fetch_certification(event)
      send_notification(certification, :action_required_email)
    end

    def handle_insufficient_hours(event)
      certification = fetch_certification(event)
      hours_data = event[:payload][:hours_data] || HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)

      NotificationService.send_email_notification(
        MemberMailer,
        {
          certification: certification,
          hours_data: hours_data,
          target_hours: HoursComplianceDeterminationService::TARGET_HOURS
        },
        :insufficient_hours_email,
        [ certification.member_email ]
      )
    end

    def handle_insufficient_community_engagement(event)
      certification = fetch_certification(event)
      payload = event[:payload]

      hours_data = payload[:hours_data]
      if hours_data.nil? && payload[:show_hours_insufficient] == true
        hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
      end

      income_key_present = payload.key?(:income_data)
      income_data =
        if income_key_present
          payload[:income_data]
        else
          IncomeComplianceDeterminationService.aggregate_income_for_certification(
            certification,
            certification_case: certification_case_for_notification(payload)
          )
        end

      show_hours_insufficient = insufficient_ce_show_hours?(payload, hours_data)
      show_income_insufficient = insufficient_ce_show_income?(payload, income_key_present, income_data)

      NotificationService.send_email_notification(
        MemberMailer,
        {
          certification: certification,
          hours_data: hours_data,
          income_data: income_data,
          target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
          target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY,
          show_hours_insufficient: show_hours_insufficient,
          show_income_insufficient: show_income_insufficient
        },
        :insufficient_community_engagement_email,
        [ certification.member_email ]
      )
    end

    # Mailer visibility for the hours section — derived here so determination services only pass aggregates.
    def insufficient_ce_show_hours?(payload, hours_data)
      if payload.key?(:show_hours_insufficient)
        payload[:show_hours_insufficient]
      else
        hours_data.present?
      end
    end

    # Mailer visibility for the income section — derived here so determination services only pass aggregates.
    def insufficient_ce_show_income?(payload, income_key_present, income_data)
      if payload.key?(:show_income_insufficient)
        payload[:show_income_insufficient]
      elsif income_key_present
        income_data.present?
      else
        true
      end
    end

    def handle_activity_report_approved(event)
      # Reviewer approved = member is compliant
      certification = fetch_certification(event)
      send_notification(certification, :compliant_email)
    end

    def handle_activity_report_denied(event)
      # Reviewer denied = member is not compliant
      handle_insufficient_hours(event)
    end

    def fetch_certification(event)
      certification_id = event[:payload][:certification_id]
      Certification.find(certification_id)
    end

    # When recomputing aggregates for a notification, prefer the case from the event payload so member
    # income matches the case under workflow (same as CommunityEngagementCheckService / staff show).
    def certification_case_for_notification(payload)
      case_id = payload[:case_id]
      return nil if case_id.blank?

      CertificationCase.find_by(id: case_id)
    end

    def send_notification(certification, email_method)
      NotificationService.send_email_notification(
        MemberMailer,
        { certification: certification },
        email_method,
        [ certification.member_email ]
      )
    end
  end
end
