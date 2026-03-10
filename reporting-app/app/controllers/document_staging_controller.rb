# frozen_string_literal: true

class DocumentStagingController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize StagedDocument
    @staged_documents = service.submit(files: Array(create_params), user: current_user)
    @staged_document_ids = @staged_documents.map(&:id)

    # TODO: Redirect to page with multiple new activities with pre-filled document fields
  rescue DocumentStagingService::ValidationError => e
    @error = e.message
    render :create, status: :unprocessable_entity
  end

  def lookup
    authorize StagedDocument
    @staged_documents = policy_scope(StagedDocument).where(id: lookup_params[:ids])
    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
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
