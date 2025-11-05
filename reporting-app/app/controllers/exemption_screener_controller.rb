# frozen_string_literal: true

class ExemptionScreenerController < ApplicationController
  before_action :set_certification_case, only: %i[ index ]
  before_action :set_certification, if: -> { @certification_case.present? }

  # TODO: figure out authz
  skip_after_action :verify_policy_scoped

  def index
    if @certification_case.blank?
      redirect_to dashboard_path
    end
  end

  private
    def set_certification_case
      @certification_case = CertificationCase.find_by(id: params[:certification_case_id])
    end

    def set_certification
      @certification = Certification.find_by(id: @certification_case.certification_id)
    end
end
