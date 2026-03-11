# frozen_string_literal: true

class DocumentStagingController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize StagedDocument
    @staged_documents = service.submit(files: Array(create_params), user: current_user)

    if @staged_documents.any?
      @staged_document_ids = @staged_documents.map(&:id)
      # TODO: Redirect to document upload status page
    else
      # redirect back to the activity report application form document upload step with a notice that no files were uploaded
    end
  rescue DocumentStagingService::ValidationError => e
    @error = e.message
    render :create, status: :unprocessable_entity
  end

  def lookup
    authorize StagedDocument
    @staged_documents = policy_scope(StagedDocument).where(id: lookup_params[:ids])
    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
  end

  def doc_ai_upload_status
    # renders the doc_ai_upload_status.html.erb view
    # view looks exactly like the doc_ai_upload.html.erb view, but now with each file's status displayed.
    # There is now a Save time with AI dialog from the start page that is displayed here.
    # Below that are two buttons: "Save and continue" and "Skip AI, and enter my details manually"
    # While we are waiting for the DocAI results to be processed, a loading modal is displayed.
    # See screenshot at /Users/baonguyen/Documents/NavaGithub/oscer/docs/architecture/doc-ai-integration/frontend/Screenshot 2026-03-11 at 10.59.30 AM.png
  end

  private

  def create_params
    params.permit(files: [])[:files].reject(&:blank?)
  end

  def lookup_params
    params.permit(ids: [])
  end

  def service
    @service ||= DocumentStagingService.new
  end
end
