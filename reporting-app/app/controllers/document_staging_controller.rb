# frozen_string_literal: true

class DocumentStagingController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize StagedDocument
    @staged_documents = service.submit(files: Array(create_params), user: current_user)

    if @staged_documents.any?
      redirect_to doc_ai_upload_status_document_staging_path(
        ids: @staged_documents.map(&:id),
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
    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
    @activity_report_application_form_id = params[:activity_report_application_form_id]
  end

  def lookup
    authorize StagedDocument
    @staged_documents = policy_scope(StagedDocument).where(id: lookup_params[:ids])
    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
  end

  private

  def create_params
    params.permit(:activity_report_application_form_id, files: [])[:files].reject(&:blank?)
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
