# frozen_string_literal: true

# Service for creating certifications
# Handles creation of ExternalHourlyActivity and ExternalIncomeActivity records
# (from member and household data) and CertificationOrigin tracking
class Certifications::CreationService
  attr_reader :create_request, :certification

  def initialize(certification)
    @certification = certification
  end

  # Creates certification with associated records in a transaction
  # @return [Certification] The created certification
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def call
    ActiveRecord::Base.transaction do
      # Create external activities FIRST (before certification)
      create_external_hourly_activities
      create_member_income_activities
      create_household_income_activities

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
      # Any other hourless activity still falls through to ExternalHourlyActivityService, which rejects it.
      next if activity_data.education_enrollment? && activity_data.clock_hours.blank?

      ExternalHourlyActivityService.create_entry(
        member_id: certification.member_id,
        category: activity_data.category,
        hours: activity_data.clock_hours,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: ExternalHourlyActivity::SOURCE_TYPES[:api],
        source_id: nil
      )
    end
  end

  # Income reaches the member through two paths, both stored as ExternalIncomeActivity rows:
  # verified income activities in member_data, and household members' reported gross income.
  def create_member_income_activities
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

  def create_household_income_activities
    return unless certification.household_data&.members.present?

    certification.household_data.members.each do |household_member|
      next if household_member.same_person_as?(certification.member_data)

      Array(household_member.gross_incomes).each do |gross_income|
        ExternalIncomeActivityService.create_entry(
          member_id: certification.member_id,
          category: ExternalIncomeActivity::CATEGORY_HOUSEHOLD,
          gross_income: gross_income.gross_income,
          period_start: gross_income.period_start,
          period_end: gross_income.period_end,
          source_type: ExternalIncomeActivity::SOURCE_TYPES[:api],
          source_id: nil,
          reported_at: Time.current,
          recalculate_income_compliance: false
        )
      end
    end
  end
end
