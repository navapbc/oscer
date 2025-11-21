# frozen_string_literal: true

class CertificationsController < StaffController
  before_action :set_certification, only: %i[ show update ]

  # GET /certifications
  # GET /certifications.json
  def index
    @certifications = policy_scope(Certification.all)
  end

  # GET /certifications/1
  def show
  end

  # GET /certifications/new
  def new
    @certification_form = authorize Certification.new
  end

  # POST /certifications/
  def create
    @certification = Certification.new(certification_params.except(:certification_requirements))

    authorize @certification

    requirement_params = certification_params.fetch(:certification_requirements, {})
    begin
      @certification.certification_requirements = certification_service.certification_requirements_from_input(requirement_params)
    rescue ActiveModel::ValidationError => e
      render json: { certification_requirements: e.model.errors }, status: :unprocessable_content
      return
    end

    if @certification.save
      render :show, status: :created, location: @certification
    else
      render json: @certification.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /certifications/1
  # PATCH/PUT /certifications/1.json
  def update
    if @certification.update(certification_params)
      render :show, status: :ok, location: @certification
    else
      render json: @certification.errors, status: :unprocessable_content
    end
  end

  private
    def set_certification
      @certification = authorize Certification.find(params[:id])
    end

    def certification_service
      CertificationService.new
    end

    # Only allow a list of trusted parameters through.
    def certification_params
      # support both top-level params and under a "certification" key (for HTML form)
      if params&.has_key?(:certification)
        cert_params = params.fetch(:certification)
      else
        cert_params = params
      end

      cert_params.permit(
        :member_id,
        :case_number,
        :certification_requirements,
        :member_data,
        certification_requirements: {},
        member_data: {}
      ).tap do |cert_params|
        begin
          # handle HTML form input of the JSON blob as a string
          if cert_params[:certification_requirements].present? && cert_params[:certification_requirements].is_a?(String)
            parsed_requirements = JSON.parse(cert_params[:certification_requirements])

            # Permit all Requirements and RequirementParams attributes, plus nested params hash
            permitted_keys = (Certifications::Requirements.attribute_names | Certifications::RequirementParams.attribute_names).map(&:to_sym)

            cert_params[:certification_requirements] =
              ActionController::Parameters.new(parsed_requirements).permit(
                *Certifications::Requirements.attribute_names.map(&:to_sym).excluding(:months_that_can_be_certified, :params),
                months_that_can_be_certified: [],
                params: Certifications::RequirementParams.attribute_names.map(&:to_sym)
              )
          end

          # handle HTML form input of the JSON blob as a string
          if cert_params[:member_data].present? && cert_params[:member_data].is_a?(String)
            cert_params[:member_data] = JSON.parse(cert_params[:member_data])
          end
        rescue JSON::ParserError => e
          raise ActionController::BadRequest.new(e.message)
        end
      end
    end
end
