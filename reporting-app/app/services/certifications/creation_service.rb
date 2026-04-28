# frozen_string_literal: true

# Service for creating certifications
# Handles creation of ExParteActivity records and CertificationOrigin tracking
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
      # Create ex parte activities FIRST (before certification)
      create_ex_parte_activities
      create_incomes

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

  def create_ex_parte_activities
    return unless certification.member_data&.activities.present?

    hourly_activities = certification.member_data.activities.select { |a| a.type == "hourly" }

    hourly_activities.each do |activity_data|
      result = ExParteActivityService.create_entry(
        member_id: certification.member_id,
        category: activity_data.category,
        hours: activity_data.hours,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: ExParteActivity::SOURCE_TYPES[:api],
        source_id: nil
      )

      # Handle service error response
      if result.is_a?(Hash) && result[:error]
        # Create a dummy record to use RecordInvalid pattern
        activity = ExParteActivity.new
        activity.errors.add(:base, result[:error])
        raise ActiveRecord::RecordInvalid.new(activity)
      end
    end
  end

  def create_incomes
    return unless certification.member_data&.activities.present?

    income_activities = certification.member_data.activities.select { |a| a.type == "income" }

    income_activities.each do |activity_data|
      result = IncomeService.create_entry(
        member_id: certification.member_id,
        category: activity_data.category,
        gross_income: activity_data.gross_income,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: activity_data.source,
        source_id: nil,
        reported_at: activity_data.reported_at || Time.current,
        employer: activity_data.employer,
        recalculate_income_compliance: false
      )

      if result.is_a?(Hash) && result[:error]
        row = Income.new
        row.errors.add(:base, result[:error])
        raise ActiveRecord::RecordInvalid.new(row)
      end
    end
  end
end
