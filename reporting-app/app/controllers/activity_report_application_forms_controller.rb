# frozen_string_literal: true

class ActivityReportApplicationFormsController < ApplicationController
  before_action :set_activity_report_application_form, only: %i[
    show
    edit
    review
    update
    submit
    destroy
  ]
  before_action :authenticate_user!
  before_action :set_certification_case, only: %i[ edit update ]

  # GET /activity_report_application_forms/1 or /activity_report_application_forms/1.json
  def show
  end

  # GET /activity_report_application_forms/new
  def new
    authorize ActivityReportApplicationForm
    if params[:certification_case_id].blank?
      redirect_to dashboard_path, alert: "Cannot create activity report without a certification case"
      return
    end
    @certification_case = certification_service.find(params[:certification_case_id], hydrate: false)
  end

  # POST /activity_report_application_forms
  def create
    @activity_report_application_form = authorize ActivityReportApplicationForm.new(activity_report_application_form_create_params)
    @activity_report_application_form.user_id = current_user.id

    respond_to do |format|
      if @activity_report_application_form.save
        format.html { redirect_to edit_activity_report_application_form_path(@activity_report_application_form) }
        format.json { render :show, status: :created, location: @activity_report_application_form }
      else
        flash[:errors] = @activity_report_application_form.errors.full_messages
        format.html { redirect_to dashboard_path }
        format.json { render json: @activity_report_application_form.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /activity_report_application_forms/1/edit
  def edit
    @certification_requirements = @certification_case.certification.certification_requirements

    respond_to do |format|
      format.html
      format.json { render json: @activity_report_application_form.as_json }
    end
  end

  # GET /activity_report_application_forms/1/review
  def review
  end

  # PATCH/PUT /activity_report_application_forms/1 or /activity_report_application_forms/1.json
  def update
    @certification_requirements = @certification_case.certification.certification_requirements
    @activity_report_application_form.assign_attributes(
      activity_report_application_form_params.merge(
        number_of_months_to_certify: @certification_requirements.number_of_months_to_certify,
        months_that_can_be_certified: @certification_requirements.months_that_can_be_certified,
      )
    )

    respond_to do |format|
      if @activity_report_application_form.save(context: :reporting_period_selection)
        format.html { redirect_to @activity_report_application_form, notice: "Activity report application form was successfully updated." }
        format.json { render :show, status: :ok, location: review_activity_report_application_form_path(@activity_report_application_form) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @activity_report_application_form.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /activity_report_application_forms/1/submit
  def submit
    if @activity_report_application_form.submit_application
      redirect_to @activity_report_application_form, notice: "Application submitted"
    else
      flash[:errors] = @activity_report_application_form.errors.full_messages
      redirect_to edit_activity_report_application_form_url(@activity_report_application_form)
    end
  end

  # DELETE /activity_report_application_forms/1 or /activity_report_application_forms/1.json
  def destroy
    @activity_report_application_form.destroy!

    respond_to do |format|
      format.html { redirect_to dashboard_path, status: :see_other, notice: "Activity report application form was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_activity_report_application_form
    @activity_report_application_form = authorize ActivityReportApplicationForm.find(params[:id])
  end

  def default_reporting_source
    Rails.application.config.reporting_source
  end

  def activity_report_application_form_create_params
    params.require(:activity_report_application_form).permit(:certification_case_id)
  end

  def set_certification_case
    @certification_case = certification_service.find(@activity_report_application_form.certification_case_id)
  end

  def certification_service
    @certification_service ||= CertificationService.new
  end

  def activity_report_application_form_params
    permitted_params = params.require(:activity_report_application_form).permit(
      :employer_name,
      :minutes,
      reporting_periods: [],
    )

    # Convert JSON strings to hash format for YearMonth
    # TODO: Update strata-sdk to support setting strata array attributes from date strings (e.g. "2023-01").
    # Linear Issue: TSS-375(https://linear.app/nava-platform/issue/TSS-375/add-ability-to-set-array-attributes)
    # Remove the JSON parsing once strata-sdk supports this.
    if permitted_params[:reporting_periods].present?
      permitted_params[:reporting_periods] = permitted_params[:reporting_periods].filter_map do |json_string|
        next if json_string.blank?

        begin
          date = JSON.parse(json_string).symbolize_keys
          # Validate the structure of the parsed JSON
          unless date[:year].is_a?(Integer) && date[:month].is_a?(Integer)
            raise ArgumentError, "Invalid reporting period format"
          end

          date
        rescue JSON::ParserError
          nil # Skip invalid JSON
        end
      end
    end

    permitted_params
  end
end
