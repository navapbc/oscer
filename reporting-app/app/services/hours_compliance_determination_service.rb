# frozen_string_literal: true

class HoursComplianceDeterminationService
  TARGET_HOURS = ENV.fetch("CE_TARGET_MONTHLY_HOURS", 80).to_i

  class << self
    include ActivityAggregator

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
      kase = certification_case_for_certification(certification)
      raise ActiveRecord::RecordNotFound, "Couldn't find CertificationCase for Certification #{certification_id}" unless kase

      # TODO: the logic behind which forms are updated tbd
      application_form = ActivityReportApplicationForm.where(certification_case_id: kase.id).first
      hours_data = aggregate_hours_for_certification(certification, application_form:)
      outcome = determine_outcome(hours_data[:total_hours])

      kase.record_hours_compliance(outcome, hours_data)
    end

    # PUBLIC: Aggregate hours from both ExternalHourlyActivity and approved Activity records
    # Called by business process notification steps to get hours data for emails.
    #
    # @param certification [Certification]
    # @param application_form [ActivityReportApplicationForm, nil]
    # @param external_hourly_activities [ActiveRecord::Relation<ExternalHourlyActivity>, Array<ExternalHourlyActivity>, nil]
    #   When set, skips fetching external rows again (e.g. staff +#show+ already loaded them).
    # @param member_hour_activity_rows [Array<Activity>, nil] When set, skips
    #   +member_hour_activities_for_certification+ for totals/ids (rows must match +application_form:+ when passed).
    # @return [Hash] with total_hours, hours_by_category, hours_by_source, etc.
    def aggregate_hours_for_certification(
      certification,
      application_form: nil,
      external_hourly_activities: nil,
      member_hour_activity_rows: nil
    )
      external_sources = external_hourly_activities.nil? ? fetch_external_hourly_activities(certification) : external_hourly_activities
      external_hours = summarize_hours(external_sources)

      member_hours = if member_hour_activity_rows.nil?
        member_hours_from_activities(certification, application_form:)
      else
        summarize_hours(member_hour_activity_rows)
      end

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

    # Member-reported activity rows on the case activity report that carry hours (non-nil +hours+ column).
    # Used by staff +CertificationCasesController#show+ for the "Hours reported" table, parallel to
    # +IncomeComplianceDeterminationService.member_income_activities_for_certification+.
    #
    # @param certification [Certification]
    # @param application_form [ActivityReportApplicationForm, nil]
    # @return [ActiveRecord::Relation<Activity>]
    def member_hour_activities_for_certification(certification, application_form:)
      return Activity.none unless application_form

      application_form.activities.where.not(hours: nil).order(:month, :created_at)
    end

    # Check if total hours meet the compliance threshold
    # @param total_hours [Float]
    # @return [Boolean]
    def compliant_for_total_hours?(total_hours)
      total_hours.to_f >= TARGET_HOURS
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
      compliant_for_total_hours?(total_hours) ? :compliant : :not_compliant
    end

    def merge_category_hours(external, member)
      (external.keys | member.keys).each_with_object({}) do |category, result|
        result[category] = (external[category] || 0.0) + (member[category] || 0.0)
      end
    end

    def member_hours_from_activities(certification, application_form: nil)
      # +member_hour_activities_for_certification+ orders by month / created_at for the staff UI table.
      # +summarize_hours+ adds +GROUP BY :category+, which Postgres rejects unless those ORDER BY columns
      # are in the GROUP BY. Strip the ORDER BY before aggregating.
      rel = member_hour_activities_for_certification(certification, application_form:).reorder(nil)
      summarize_hours(rel)
    end
  end
end
