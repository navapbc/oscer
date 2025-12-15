# frozen_string_literal: true

class Demo::CertificationsController < ApplicationController
  layout "demo"

  before_action :set_regions

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def new
    @form = Demo::Certifications::CreateForm.new_for_certification_type(
      params.fetch(:certification_type, nil)
    )
  end

  def create
    @form = Demo::Certifications::CreateForm.new(form_params)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_content
    end

    @certification = @form.to_certification

    if !@certification
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_content
    end

    begin
      ActiveRecord::Base.transaction do
        # Create ex parte activities FIRST (before certification)
        create_ex_parte_activities

        # Save certification
        unless @certification.save
          raise ActiveRecord::RecordInvalid.new(@certification)
        end
      end

      redirect_to certification_path(@certification)
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:errors] = e.record.errors.full_messages
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_regions
    @regions = User.regions
  end

  def form_params
    params.require(:demo_certifications_create_form)
          .permit(Demo::Certifications::CreateForm.attribute_names.map(&:to_sym))
  end

  def create_ex_parte_activities
    return unless @certification.member_data&.activities.present?

    hourly_activities = @certification.member_data.activities.select { |a| a.type == "hourly" }

    hourly_activities.each do |activity_data|
      ex_parte_activity = build_ex_parte_activity(activity_data)

      unless ex_parte_activity.save
        raise ActiveRecord::RecordInvalid.new(ex_parte_activity)
      end
    end
  end

  def build_ex_parte_activity(activity_data)
    ExParteActivity.new(
      member_id: @certification.member_id,
      category: activity_data.category,
      hours: activity_data.hours,
      period_start: activity_data.period_start,
      period_end: activity_data.period_end,
      source_type: ExParteActivity::SOURCE_TYPES[:manual],
      source_id: nil
    )
  end
end
