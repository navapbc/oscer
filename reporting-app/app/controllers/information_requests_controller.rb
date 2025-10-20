# frozen_string_literal: true

class InformationRequestsController < StaffController
  def show
    @information_request = InformationRequest.find(params[:id])
  end
end
