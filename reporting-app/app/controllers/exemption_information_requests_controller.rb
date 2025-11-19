# frozen_string_literal: true

class ExemptionInformationRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_information_request, only: %i[ edit update ]

  def edit
  end

  def update
    respond_to do |format|
      result = TaskService.fulfill_information_request(@information_request, information_request_params)
      if result[:success]
        format.html { redirect_to dashboard_path, notice: "Information request fulfilled" }
        format.json { render :show, status: :ok, location: @information_request }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @information_request.errors, status: :unprocessable_content }
      end
    end
  end

  private

  def set_information_request
    @information_request = authorize ExemptionInformationRequest.find(params[:id])
  end

  def information_request_params
    params.require(:exemption_information_request).permit(:member_comment, supporting_documents: [])
  end
end
