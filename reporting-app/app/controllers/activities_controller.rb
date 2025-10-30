# frozen_string_literal: true

class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity_report_application_form
  before_action :set_activity, only: %i[ show edit update documents upload_documents destroy ]

  # GET /activities/1 or /activities/1.json
  def show
    authorize @activity_report_application_form
  end

  # GET /activities/new
  def new
    @activity = @activity_report_application_form.activities.build
    authorize @activity_report_application_form, :edit?
  end

  # GET /activities/1/edit
  def edit
    authorize @activity_report_application_form, :edit?
  end

  # GET /activities/1/documents
  def documents
    authorize @activity_report_application_form, :edit?
  end

  # GET /activities/1/upload_documents
  def upload_documents
    authorize @activity_report_application_form, :edit?

    supporting_documents = params.require(:activity).permit(supporting_documents: [])[:supporting_documents]
    @activity.supporting_documents.attach(supporting_documents)

    respond_to do |format|
      if @activity_report_application_form.save
        format.html { redirect_to documents_activity_report_application_form_activity_path(@activity_report_application_form, @activity) }
        format.json { render :show, status: :ok, location: @activity }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /activities or /activities.json
  def create
    authorize @activity_report_application_form, :update?

    @activity = @activity_report_application_form.activities.build(activity_params)

    respond_to do |format|
      if @activity_report_application_form.save
        format.html { redirect_to documents_activity_report_application_form_activity_path(@activity_report_application_form, @activity) }
        format.json { render :show, status: :created, location: @activity }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /activities/1 or /activities/1.json
  def update
    authorize @activity_report_application_form, :update?

    @activity.attributes = activity_params

    respond_to do |format|
      if @activity_report_application_form.save
        format.html { redirect_to documents_activity_report_application_form_activity_path(@activity_report_application_form, @activity) }
        format.json { render :show, status: :ok, location: @activity }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /activities/1 or /activities/1.json
  def destroy
    authorize @activity_report_application_form, :update?

    @activity_report_application_form.activities = @activity_report_application_form.activities.reject { |activity| activity.id == params[:id] }
    @activity_report_application_form.save!

    respond_to do |format|
      format.html { redirect_to activity_report_application_form_path(@activity_report_application_form), status: :see_other, notice: "Activity was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_activity
      @activity = @activity_report_application_form.activities_by_id[params[:id]]
    end

    def set_activity_report_application_form
      @activity_report_application_form = ActivityReportApplicationForm.find(params[:activity_report_application_form_id])
    end

    # Only allow a list of trusted parameters through.
    def activity_params
      params.require(:activity).permit(:month, :hours, :name)
    end
end
