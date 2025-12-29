# frozen_string_literal: true

class InformationRequestsController < StaffController
  def show
    # Explicitly use InformationRequestPolicy for staff access
    # (The STI subclass policies are for member access only)
    @information_request = authorize InformationRequest.find(params[:id]), policy_class: InformationRequestPolicy
  end
end
