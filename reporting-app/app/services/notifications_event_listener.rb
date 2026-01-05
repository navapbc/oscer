# frozen_string_literal: true

# Listens to domain events and sends appropriate email notifications.
# This decouples notifications from the business process workflow.
#
# Subscribed events and their notifications:
# - DeterminedExempt → exempt_email
# - DeterminedHoursMet → compliant_email
# - DeterminedActionRequired → action_required_email
# - DeterminedHoursInsufficient → insufficient_hours_email
# - ActivityReportApproved → compliant_email (reviewer determined compliance)
# - ActivityReportDenied → insufficient_hours_email (reviewer determined non-compliance)
class NotificationsEventListener
  class << self
    def subscribe
      Strata::EventManager.subscribe("DeterminedExempt", method(:handle_exempt))
      Strata::EventManager.subscribe("DeterminedHoursMet", method(:handle_compliant))
      Strata::EventManager.subscribe("DeterminedActionRequired", method(:handle_action_required))
      Strata::EventManager.subscribe("DeterminedHoursInsufficient", method(:handle_insufficient_hours))
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
