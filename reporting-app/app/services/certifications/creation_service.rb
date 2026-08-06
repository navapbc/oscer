# frozen_string_literal: true

# Service for creating certifications
# Handles creation of ExternalHourlyActivity records and CertificationOrigin tracking
class Certifications::CreationService
  attr_reader :create_request, :certification

  # One credit hour is 12.99 clock hours per month (3 hours per week over a 4.33 week month)
  # per the Federal Register.
  CREDIT_HOURS_MULTIPLIER = BigDecimal("12.99")

  def initialize(certification)
    @certification = certification
  end

  # Creates certification with associated records in a transaction
  # @return [Certification] The created certification
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def call
    ActiveRecord::Base.transaction do
      # Create external hourly activities FIRST (before certification)
      create_external_hourly_activities
      create_external_income_activities

      # Save certification
      unless certification.save
        raise ActiveRecord::RecordInvalid.new(certification)
      end

      # Track origin
      create_origin_record
    end

    certification
  end

  private

  def create_origin_record
    CertificationOrigin.create!(
      certification_id: certification.id,
      source_type: CertificationOrigin::SOURCE_TYPE_API,
      source_id: nil
    )
  end

  def create_external_hourly_activities
    return unless certification.member_data&.activities.present?

    hourly_activities = certification.member_data.activities.select { |a| a.type == "hourly" }

    hourly_activities.each do |activity_data|
      next unless activity_data.verified?

      hours = if activity_data.hours.nil? && activity_data.education_credit_hours?
                activity_data.credit_hours * CREDIT_HOURS_MULTIPLIER
      else
                activity_data.hours
      end

      ExternalHourlyActivityService.create_entry(
        member_id: certification.member_id,
        category: activity_data.category,
        hours: hours,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: ExternalHourlyActivity::SOURCE_TYPES[:api],
        source_id: nil
      )
    end
  end

  def create_external_income_activities
    return unless certification.member_data&.activities.present?

    income_activities = certification.member_data.activities.select { |a| a.type == "income" }

    income_activities.each do |activity_data|
      next unless activity_data.verified?

      ExternalIncomeActivityService.create_entry(
        member_id: certification.member_id,
        category: activity_data.category,
        gross_income: activity_data.gross_income,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: activity_data.source,
        source_id: nil,
        reported_at: activity_data.reported_at || Time.current,
        employer: activity_data.employer || activity_data.name,
        recalculate_income_compliance: false
      )
    end
  end
end
