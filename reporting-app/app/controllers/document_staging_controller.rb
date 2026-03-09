# frozen_string_literal: true

class DocumentStagingController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_policy_scoped

  def create
    authorize StagedDocument
    @staged_documents = service.submit(signed_ids: params[:signed_ids] || [], user: current_user)
    @staged_document_ids = @staged_documents.map(&:id)
  rescue DocumentStagingService::ValidationError => e
    @error = e.message
    render :create, status: :unprocessable_entity
  end

  def lookup
    authorize StagedDocument
    @staged_documents = StagedDocument.where(id: params[:ids], user_id: current_user.id)
    @all_complete = @staged_documents.any? && @staged_documents.none?(&:pending?)
  end

  private

  def service
    @service ||= DocumentStagingService.new
  end
end
