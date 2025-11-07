# frozen_string_literal: true

class ExemptionApplicationFormsController < ApplicationController
  before_action :set_exemption_application_form, only: %i[ show edit update destroy review submit documents upload_documents ]
  before_action :set_certification_case, only: %i[ show ]
  before_action :create_exemption_application_form, only: %i[ create ]

  # GET /exemption_application_forms/1 or /exemption_application_forms/1.json
  def show
  end

  # GET /exemption_application_forms/new
  def new
    @exemption_application_form = authorize ExemptionApplicationForm.new(
      certification_case_id: params[:certification_case_id]
    )
  end

  # GET /exemption_application_forms/1/edit
  def edit
    render :exemption_type
  end

  # POST /exemption_application_forms or /exemption_application_forms.json
  def create
    respond_to do |format|
      if @exemption_application_form.valid?
        format.html { redirect_to edit_exemption_application_form_path(@exemption_application_form) }
        format.json { render :show, status: :created, location: @exemption_application_form }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @exemption_application_form.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /exemption_application_forms/1 or /exemption_application_forms/1.json
  def update
    respond_to do |format|
      if @exemption_application_form.update(exemption_application_form_params)
        format.html { redirect_to documents_exemption_application_form_path(@exemption_application_form) }
        format.json { render :show, status: :ok, location: @exemption_application_form }
      else
        format.html { render :exemption_type, status: :unprocessable_content }
        format.json { render json: @exemption_application_form.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /exemption_application_forms/1 or /exemption_application_forms/1.json
  def destroy
    @exemption_application_form.destroy!

    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: "Exemption application form was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # GET /exemption_application_forms/1/review
  def review
  end

  # POST /exemption_application_forms/1/submit
  def submit
    if @exemption_application_form.submit_application
      redirect_to @exemption_application_form, notice: "Exemption application form submitted"
    else
      flash[:errors] = @exemption_application_form.errors.full_messages
      redirect_to edit_exemption_application_form_url(@exemption_application_form)
    end
  end

  # GET /exemption_application_forms/1/documents
  def documents
  end

  # POST /exemption_application_forms/1/upload_documents
  def upload_documents
    supporting_documents = params.require(:exemption_application_form).permit(supporting_documents: [])[:supporting_documents]
    @exemption_application_form.supporting_documents.attach(supporting_documents)

    respond_to do |format|
      if @exemption_application_form.save
        format.html { redirect_to documents_exemption_application_form_path(@exemption_application_form) }
        format.json { render :show, status: :ok, location: @exemption_application_form }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @exemption_application_form.errors, status: :unprocessable_content }
      end
    end
  end

  private
    def set_exemption_application_form
      @exemption_application_form = authorize ExemptionApplicationForm.find(params[:id])
    end

    def exemption_application_form_params
      params.require(:exemption_application_form).permit(
        :exemption_type,
        :certification_case_id
        )
    end

    def set_certification_case
      @certification_case = CertificationCase.find_by(id: @exemption_application_form.certification_case_id)
    end

    def create_exemption_application_form
      @exemption_application_form = ExemptionApplicationForm.new(exemption_application_form_params)
      @exemption_application_form.user_id = current_user.id
      authorize @exemption_application_form
      @exemption_application_form.save!
    rescue ActiveRecord::RecordInvalid => e
      if e.record.errors[:certification_case_id].include?("has already been taken")
        redirect_to dashboard_path, notice: "An exemption application already exists for this certification case"
      else
        raise
      end
    end
end
