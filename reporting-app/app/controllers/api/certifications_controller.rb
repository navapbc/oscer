# frozen_string_literal: true

class Api::CertificationsController < ApiController
  before_action :set_certification, only: %i[ show ]

  # @summary Retrieve a Certification record
  # @tags certifications
  #
  # @response A Certification(200) [Reference:#/components/schemas/CertificationResponseBody]
  def show
    render_data(Api::Certifications::Response.from_certification(@certification))
  end

  # @summary Create a Certification record
  # @tags certifications
  #
  # @request_body The Certification data. [Reference:#/components/schemas/CertificationCreateRequestBody]
  # @request_body_example Fully specified certification requirements [Reference:#/components/schemas/CertificationCreateRequestBody/examples/fully_specified_certification_requirements]
  # @request_body_example Certification type [Reference:#/components/schemas/CertificationCreateRequestBody/examples/certification_type]
  # @response Created Certification.(201) [Reference:#/components/schemas/CertificationResponseBody]
  # @response User error.(400) [Reference:#/components/schemas/ErrorResponseBody]
  def create
    create_request = Api::Certifications::CreateRequest.from_request_params(params)

    if !create_request.valid?
      return render_errors(create_request)
    end

    # TODO: handle this better here?
    # case create_request.certification_requirements
    # when Certifications::Requirements
    #   # we are good to go
    # when Certifications::RequirementParams
    # end
    begin
      certification_requirements = certification_service.certification_requirements_from_input(create_request.certification_requirements.attributes)
    rescue ActiveModel::ValidationError => e
      return render_errors({ certification_requirements: e.model.errors })
    end

    cert_attrs = create_request.attributes.merge({ certification_requirements: certification_requirements })
    @certification = Certification.new(cert_attrs)

    authorize @certification

    if certification_service.save_new(@certification)
      render_data(
        Api::Certifications::Response.from_certification(@certification),
        status: :created
      )
    else
      render_errors(@certification.errors)
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_certification
      @certification = authorize Certification.find(params[:id])
    end

    def certification_service
      CertificationService.new
    end
end
