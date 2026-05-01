# frozen_string_literal: true

class HoursComplianceDeterminationService
  TARGET_HOURS = ENV.fetch("CE_TARGET_MONTHLY_HOURS", 80).to_i

  class << self
    include ActivityAggregator

    # Called by CertificationBusinessProcess at EX_PARTE_CE_CHECK step (initial check)
    # Publishes different events based on whether external hours exist:
    # - DeterminedActionRequired: No external hours found, member needs to report from scratch
    # - DeterminedHoursInsufficient: Has some external hours but needs more
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.record_hours_compliance(outcome, hours_data)

      if outcome == :compliant
        Strata::EventManager.publish("DeterminedHoursMet", {
          case_id: kase.id,
          certification_id: certification.id
        })
      elsif hours_data[:hours_by_source][:external] > 0
        # Has some external hours but needs more - send insufficient hours email
        Strata::EventManager.publish("DeterminedHoursInsufficient", {
          case_id: kase.id,
          certification_id: certification.id,
          hours_data: hours_data
        })
      else
        # No external hours found - send action required email
        Strata::EventManager.publish("DeterminedActionRequired", {
          case_id: kase.id,
          certification_id: certification.id
        })
      end
    end

    # Called by CertificationBusinessProcess after ActivityReportApproved event
    # @param kase [CertificationCase]
    def determine_after_activity_report(kase)
      perform_determination(kase, not_compliant_event: "DeterminedHoursInsufficient")
    end

    # Called by CalculateComplianceJob for async recalculation of existing certifications
    # Records determination without triggering workflow events/notifications.
    # When compliant, +record_hours_compliance+ closes the case (+CertificationCase#record_automated_ce_compliance+);
    # +IncomeComplianceDeterminationService#calculate+ follows the same close-on-compliant rule for parity.
    # @param certification_id [String]
    # @return [void]
    def calculate(certification_id)
      certification = Certification.find(certification_id)
      kase = CertificationCase.find_by!(certification_id: certification_id)

      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.record_hours_compliance(outcome, hours_data)
    end

    # PUBLIC: Aggregate hours from both ExternalHourlyActivity and approved Activity records
    # Called by business process notification steps to get hours data for emails
    # @param certification [Certification]
    # @return [Hash] with total_hours, hours_by_category, hours_by_source, etc.
    def aggregate_hours_for_certification(certification)
      external_hourly_activities = fetch_external_hourly_activities(certification)
      member_activities = fetch_member_activities(certification).where.not(hours: nil)

      external_hours = summarize_hours(external_hourly_activities)
      member_hours = summarize_hours(member_activities)

      {
        total_hours: external_hours[:total] + member_hours[:total],
        hours_by_category: merge_category_hours(external_hours[:by_category], member_hours[:by_category]),
        hours_by_source: {
          external: external_hours[:total],
          activity: member_hours[:total]
        },
        external_hourly_activity_ids: external_hours[:ids],
        activity_ids: member_hours[:ids]
      }
    end

    private

    # Shared logic for both initial and post-activity-report determination
    # @param kase [CertificationCase]
    # @param not_compliant_event [String] event name to publish when not compliant
    def perform_determination(kase, not_compliant_event:)
      certification = Certification.find(kase.certification_id)
      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.record_hours_compliance(outcome, hours_data)

      if outcome == :compliant
        Strata::EventManager.publish("DeterminedHoursMet", {
          case_id: kase.id,
          certification_id: certification.id
        })
      else
        Strata::EventManager.publish(not_compliant_event, {
          case_id: kase.id,
          certification_id: certification.id,
          hours_data: hours_data
        })
      end
    end

    def determine_outcome(total_hours)
      total_hours >= TARGET_HOURS ? :compliant : :not_compliant
    end

    def merge_category_hours(external, member)
      (external.keys | member.keys).each_with_object({}) do |category, result|
        result[category] = (external[category] || 0.0) + (member[category] || 0.0)
      end
    end
  end
end
