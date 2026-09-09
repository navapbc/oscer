# frozen_string_literal: true

# Service for creating certifications
# Handles creation of ExternalActivity records (from member and household data)
# and CertificationOrigin tracking
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
      create_member_external_activities
      create_household_external_activities

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

  # One pass: an activity reporting both hours and income becomes a single ExternalActivity row
  # per month carrying both, rather than one row in each of two tables.
  def create_member_external_activities
    return unless certification.member_data&.activities.present?

    certification.member_data.activities.each do |activity_data|
      next unless activity_data.verified?

      hours = activity_data.clock_hours
      gross_income = activity_data.gross_income
      # Only enrollment-only education activities reach here with nothing to store; they satisfy
      # the hours requirement through HoursComplianceDeterminationService instead of a row.
      next if hours.blank? && gross_income.blank?

      ExternalActivityService.create_entries(
        member_id: certification.member_id,
        category: activity_data.category,
        hours: hours,
        gross_income: gross_income,
        period_start: activity_data.period_start,
        period_end: activity_data.period_end,
        source_type: activity_data.source.presence || ExternalActivity::SOURCE_TYPES[:api],
        source_id: nil,
        reported_at: activity_data.reported_at || Time.current,
        name: activity_data.name,
        employer: activity_data.employer || activity_data.name,
        recalculate_compliance: false
      )
    end
  end

  # Household members' reported gross income, the second path income reaches the member by.
  # Kept separate because it walks household_data.members rather than member_data.activities.
  def create_household_external_activities
    return unless certification.household_data&.members.present?

    certification.household_data.members.each do |household_member|
      next if household_member.same_person_as?(certification.member_data)

      Array(household_member.gross_incomes).each do |gross_income|
        ExternalActivityService.create_entries(
          member_id: certification.member_id,
          category: ExternalActivity::CATEGORY_HOUSEHOLD,
          gross_income: gross_income.gross_income,
          period_start: gross_income.period_start,
          period_end: gross_income.period_end,
          source_type: ExternalActivity::SOURCE_TYPES[:api],
          source_id: nil,
          reported_at: Time.current,
          name: household_member_name(household_member),
          identity: [ household_member.ssn, household_member.date_of_birth ],
          recalculate_compliance: false
        )
      end
    end
  end

  # Strata::Name#full_name keeps blank middle names and suffixes as extra spaces.
  def household_member_name(household_member)
    household_member.name&.full_name&.squish.presence
  end
end
