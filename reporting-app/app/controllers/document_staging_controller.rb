# frozen_string_literal: true

class DocumentStagingController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize StagedDocument
    existing_ids = Array(create_params[:existing_ids])
    @staged_documents = service.submit(files: Array(create_params[:files].reject(&:blank?)), user: current_user)

    all_ids = existing_ids + @staged_documents.map(&:id)

    if all_ids.any?
      redirect_to doc_ai_upload_status_document_staging_path(
        ids: all_ids,
        activity_report_application_form_id: activity_report_application_form_id
      )
    else
      redirect_to doc_ai_upload_activity_report_application_form_path(
        activity_report_application_form_id
      ), notice: t("document_staging.create.no_files")
    end
  rescue DocumentStagingService::ValidationError => e
    @error = e.message
    render :create, status: :unprocessable_entity
  end

  def doc_ai_upload_status
    authorize StagedDocument
    @staged_document_ids = Array(params[:ids])
    @staged_documents = policy_scope(StagedDocument).where(id: @staged_document_ids)

    if @staged_document_ids.blank? || (@staged_documents.size != @staged_document_ids.size)
      redirect_to doc_ai_upload_activity_report_application_form_path(
        id: activity_report_application_form_id
      )
    end

    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
    @activity_report_application_form_id = activity_report_application_form_id

    return unless @all_complete && @staged_documents.any?

    validated = @staged_documents.select(&:validated?)
    if validated.any?
      flash.now[:notice] = t("document_staging.results.upload_success")
    else
      flash.now[:alert] = t("document_staging.results.upload_failure")
    end
  end

  def lookup
    authorize StagedDocument
    @staged_documents = policy_scope(StagedDocument).where(id: lookup_params[:ids])

    if @staged_documents.blank? || (@staged_documents.size != lookup_params[:ids].size)
      redirect_to doc_ai_upload_activity_report_application_form_path(
        id: activity_report_application_form_id
      )
    end

    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
  end

  private

  def create_params
    params.permit(:activity_report_application_form_id, files: [], existing_ids: [])
  end

  def lookup_params
    params.permit(ids: [])
  end

  def activity_report_application_form_id
    params[:activity_report_application_form_id]
  end

  def service
    @service ||= DocumentStagingService.new
  end
end
