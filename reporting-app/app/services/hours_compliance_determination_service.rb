# frozen_string_literal: true

class HoursComplianceDeterminationService
  TARGET_HOURS = ENV.fetch("CE_TARGET_MONTHLY_HOURS", 80).to_i

  class << self
    include ActivityAggregator

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
      outcome = determine_outcome(hours_data[:hours_by_month])

      kase.record_hours_compliance(outcome, hours_data)
    end

    # PUBLIC: Aggregate hours from both ExternalActivity and approved Activity records
    # Called by business process notification steps to get hours data for emails.
    #
    # @param certification [Certification]
    # @param application_form [ActivityReportApplicationForm, nil]
    # @param external_hourly_activities [ActiveRecord::Relation<ExternalActivity>, Array<ExternalActivity>, nil]
    #   Rows carrying hours (a +with_hours+ scope); a row also carrying income is included.
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
        hours_by_category: merge_external_with_member_data(external_hours[:by_category], member_hours[:by_category]),
        hours_by_source: {
          external: external_hours[:total],
          activity: member_hours[:total]
        },
        hours_by_month: merge_external_with_member_data(external_hours[:by_month], member_hours[:by_month]),
        external_hourly_activity_ids: external_hours[:ids],
        activity_ids: member_hours[:ids],
        enrollment_status: best_enrollment_status(certification)
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

    # Shared threshold check for combined CE (+CommunityEngagementCheckService+) and +#calculate+.
    # One month at or above the threshold is enough.
    # @param hours_by_month [Hash{Date => Numeric}]
    # @return [Boolean]
    def compliant_for_monthly_hours?(hours_by_month)
      monthly_values = hours_by_month&.values || []
      monthly_values.any? { |monthly_total| monthly_total.to_f >= TARGET_HOURS }
    end

    # Whether a verified education enrollment satisfies the hours requirement on its own.
    #
    # @param certification [Certification]
    # @return [Boolean]
    def education_enrollment_compliant?(certification)
      relevant_enrollments(certification).any?(&:qualifying_enrollment?)
    end

    private

    # The only enrollments that count toward the hours requirement.
    def relevant_enrollments(certification)
      lookback = certification&.certification_requirements&.continuous_lookback_period

      Array(certification&.member_data&.activities).select do |activity|
        activity.verified? && activity.education_enrollment? && overlaps_lookback?(activity, lookback)
      end
    end

    # Highest-ranked relevant enrollment, or nil.
    def best_enrollment_status(certification)
      statuses = Certifications::MemberData::Activity::ENROLLMENT_STATUSES

      relevant_enrollments(certification)
        .map(&:enrollment_status)
        .min_by { |status| statuses.index(status) || statuses.length }
    end

    # Different logic than +ExternalActivity.within_period+.
    def overlaps_lookback?(activity, lookback)
      return true if lookback&.start.blank? || lookback.end.blank?
      return false if activity.period_start.blank? || activity.period_end.blank?

      activity.period_start <= lookback.end.to_date.end_of_month && activity.period_end >= lookback.start.to_date
    end

    def determine_outcome(hours_by_month)
      compliant_for_monthly_hours?(hours_by_month) ? :compliant : :not_compliant
    end

    def member_hours_from_activities(certification, application_form: nil)
      summarize_hours(member_hour_activities_for_certification(certification, application_form:))
    end
  end
end
