# frozen_string_literal: true

class HoursComplianceDeterminationService
  TARGET_HOURS = ENV.fetch("CE_TARGET_MONTHLY_HOURS", 80).to_i

  class << self
    # Called by CertificationBusinessProcess at EX_PARTE_CE_CHECK step (initial check)
    # Publishes different events based on whether ex parte hours exist:
    # - DeterminedActionRequired: No ex parte hours found, member needs to report from scratch
    # - DeterminedHoursInsufficient: Has some ex parte hours but needs more
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
      elsif hours_data[:hours_by_source][:ex_parte] > 0
        # Has some ex parte hours but needs more - send insufficient hours email
        Strata::EventManager.publish("DeterminedHoursInsufficient", {
          case_id: kase.id,
          certification_id: certification.id,
          hours_data: hours_data
        })
      else
        # No ex parte hours found - send action required email
        Strata::EventManager.publish("DeterminedActionRequired", {
          case_id: kase.id,
          certification_id: certification.id,
          hours_data: hours_data
        })
      end
    end

    # Called by CertificationBusinessProcess after ActivityReportApproved event
    # @param kase [CertificationCase]
    def determine_after_activity_report(kase)
      perform_determination(kase, not_compliant_event: "DeterminedHoursInsufficient")
    end

    # Called by CalculateComplianceJob for async recalculation of existing certifications
    # Records determination without triggering workflow events/notifications
    # @param certification_id [String]
    # @return [void]
    def calculate(certification_id)
      certification = Certification.find(certification_id)
      kase = CertificationCase.find_by!(certification_id: certification_id)

      hours_data = aggregate_hours_for_certification(certification)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.record_hours_compliance(outcome, hours_data)
    end

    # PUBLIC: Aggregate hours from both ExParteActivity and approved Activity records
    # Called by business process notification steps to get hours data for emails
    # @param certification [Certification]
    # @return [Hash] with total_hours, hours_by_category, hours_by_source, etc.
    def aggregate_hours_for_certification(certification)
      lookback_period = certification.certification_requirements.continuous_lookback_period
      ex_parte_hours = aggregate_ex_parte_hours(certification.member_id, lookback_period)
      member_hours = aggregate_member_hours(certification)

      {
        total_hours: ex_parte_hours[:total] + member_hours[:total],
        hours_by_category: merge_category_hours(ex_parte_hours[:by_category], member_hours[:by_category]),
        hours_by_source: {
          ex_parte: ex_parte_hours[:total],
          activity: member_hours[:total]
        },
        ex_parte_activity_ids: ex_parte_hours[:ids],
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

    def aggregate_ex_parte_hours(member_id, lookback_period)
      entries = ExParteActivity.for_member(member_id).within_period(lookback_period)

      {
        total: entries.sum(:hours).to_f,
        by_category: entries.group(:category).sum(:hours).transform_values(&:to_f),
        ids: entries.pluck(:id)
      }
    end

    def aggregate_member_hours(certification)
      # Only include hours from approved activity reports (member-reported hours)
      certification_case = CertificationCase.find_by(certification_id: certification.id)
      return empty_hours_result unless certification_case
      return empty_hours_result unless certification_case.activity_report_approval_status == "approved"

      form = ActivityReportApplicationForm.find_by(certification_case_id: certification_case.id)
      return empty_hours_result unless form

      activities = form.activities.where.not(hours: nil)
      {
        total: activities.sum(:hours).to_f,
        by_category: activities.group(:category).sum(:hours).transform_values(&:to_f),
        ids: activities.pluck(:id)
      }
    end

    def empty_hours_result
      { total: 0.0, by_category: {}, ids: [] }
    end

    def merge_category_hours(ex_parte, member)
      (ex_parte.keys | member.keys).each_with_object({}) do |category, result|
        result[category] = (ex_parte[category] || 0.0) + (member[category] || 0.0)
      end
    end
  end
end
