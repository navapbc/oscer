# frozen_string_literal: true

class Api::CertificationsController < ApiController
  before_action :set_certification, only: %i[ show outcome ]

  # @summary Retrieve a Certification record
  # @tags certifications
  #
  # @response A Certification(200) [Reference:#/components/schemas/CertificationResponseBody]
  # @response Not found.(404) [Reference:#/components/schemas/ErrorResponseBody]
  def show
    render_data(Api::Certifications::Response.from_certification(@certification))
  end

  # @summary Retrieve a Certification record with an outcome or a 202 without
  # @tags certifications
  #
  # @response A Certification(200) [Reference:#/components/schemas/CertificationResponseBody]
  # @response Accepted(202) []
  # @response Not found.(404) [Reference:#/components/schemas/ErrorResponseBody]
  def outcome
    if @certification.outcome
      render_data(Api::Certifications::Response.from_certification(@certification))
    else
      render json: {}, status: :accepted, location: outcome_api_certification_url(@certification)
    end
  end

  # @summary Create a Certification record
  # @tags certifications
  #
  # @parameter prefer(header) [String] Header to use when want async response - respond-async
  #
  # @request_body The Certification data. [Reference:#/components/schemas/CertificationCreateRequestBody]
  # @request_body_example Fully specified certification requirements [Reference:#/components/schemas/CertificationCreateRequestBody/examples/fully_specified_certification_requirements]
  # @request_body_example Without explicit months and due date [Reference:#/components/schemas/CertificationCreateRequestBody/examples/without_explicit_months_that_can_be_certified_and_due_date]
  # @request_body_example Certification type [Reference:#/components/schemas/CertificationCreateRequestBody/examples/certification_type]
  # @response Created Certification.(201) [Reference:#/components/schemas/CertificationResponseBody]
  # @response Accepted(202) []
  # @response User error.(400) [Reference:#/components/schemas/ErrorResponseBody]
  # @response User error.(422) [Reference:#/components/schemas/ErrorResponseBody]
  def create
    create_request = Api::Certifications::CreateRequest.from_request_params(params)

    if create_request.invalid?
      return render_errors(create_request)
    end

    # Build certification from request
    certification = create_request.to_certification
    authorize certification

    begin
      service = Certifications::CreationService.new(certification)
      @certification = service.call

      if request.headers["prefer"] == "respond-async"
        render json: {}, status: :accepted, location: outcome_api_certification_url(@certification)
      else
        render_data(
          Api::Certifications::Response.from_certification(@certification),
          status: :created
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record)
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_certification
      @certification = authorize Certification.find(params[:id])
    end
end
