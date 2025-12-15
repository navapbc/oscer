# frozen_string_literal: true

# Service for creating certifications
# Handles creation of ExParteActivity records and CertificationOrigin tracking
class Certifications::CreationService
  attr_reader :create_request, :certification

  def initialize(create_request)
    @create_request = create_request
    @certification = nil
  end

  # Creates certification with associated records in a transaction
  # @return [Certification] The created certification
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def call
    @certification = create_request.to_certification

    ActiveRecord::Base.transaction do
      # Create ex parte activities FIRST (before certification)
      # TODO: use service once implemented
      # https://github.com/navapbc/oscer/issues/75
      create_ex_parte_activities

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
      ex_parte_activity = build_ex_parte_activity(activity_data)

      unless ex_parte_activity.save
        raise ActiveRecord::RecordInvalid.new(ex_parte_activity)
      end
    end
  end

  def build_ex_parte_activity(activity_data)
    ExParteActivity.new(
      member_id: certification.member_id,
      category: activity_data.category,
      hours: activity_data.hours,
      period_start: activity_data.period_start,
      period_end: activity_data.period_end,
      source_type: ExParteActivity::SOURCE_TYPES[:api],
      source_id: nil
    )
  end
end
