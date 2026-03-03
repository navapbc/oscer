# frozen_string_literal: true

class Api::HealthcheckController < ApiController
  skip_before_action :authenticate_api_request!

  # @summary Check service health
  # @tags healthcheck
  #
  # @response Response(200)
  #   [
  #     Hash{
  #       status: !String,
  #     }
  #   ]
  # @response Response(503)
  #   [
  #     Hash{
  #       status: !String,
  #     }
  #   ]
  def index
    is_healthy = true

    if is_healthy
        render json: { status: "pass" }
    else
        render json: { status: "fail" }
    end
  end
end
