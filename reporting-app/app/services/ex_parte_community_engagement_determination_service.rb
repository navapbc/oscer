# frozen_string_literal: true

# Ex parte community engagement: evaluate **hours first**. If the hours threshold is not met,
# evaluate **income** and publish income-specific Strata events (parallel names to the hours path).
# Income event payloads always include a generic `hours_data` key (same shape as hours aggregates)
# so notifications and future combined templates can use both dimensions.
class ExParteCommunityEngagementDeterminationService
  class << self
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)

      if hours_compliant?(hours_data)
        HoursComplianceDeterminationService.determine(kase)
      else
        IncomeComplianceDeterminationService.determine(kase, hours_context: hours_data)
      end
    end

    private

    def hours_compliant?(hours_data)
      hours_data[:total_hours].to_d >= HoursComplianceDeterminationService::TARGET_HOURS
    end
  end
end
