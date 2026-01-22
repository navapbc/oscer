# frozen_string_literal: true

class ApiController < ActionController::Metal
  # Skip StrongParameters as the API endpoints should be using dedicated I/O
  # models.
  ActionController::API.without_modules(:StrongParameters).each do |left|
    include left
  end

  ActiveSupport.run_load_hooks(:action_controller_api, self)
  ActiveSupport.run_load_hooks(:action_controller, self)

  include Pundit::Authorization

  before_action :authenticate_api_request!

  def render_errors(errors, status = :unprocessable_content)
    # handle being given an ActiveModel (or any object) with an errors method
    if errors.respond_to?(:errors) && errors.errors.any?
      errors = errors.errors
    end

    # handle being given a validation exception
    if errors.is_a?(ActiveModel::ValidationError)
      errors = errors.model.errors
    end

    # then handle rendering the errors themselves
    case errors
    when ActiveModel::Errors
      msgs = format_active_model_errors(errors)
    when Array
      msgs = errors
    when String
      msgs = [ errors ]
    else
      raise TypeError, "Unexpected errors type: #{errors.class}"
    end
    render json: { errors: msgs }, status: status
  end

  def render_data(data, status: :ok)
    render json: data, status: status
  end

  private

  def format_active_model_errors(errors)
    errors.details.flat_map do |field_name, field_errs|
      field_errs.map { |err| err.merge(field: field_name) }
    end
  end

  def authenticate_api_request!
    strategy = Strata::Auth::Strategies::Hmac.new(secret_key: Rails.configuration.api_secret_key)
    authenticator = Strata::ApiAuthenticator.new(strategy: strategy)
    
    begin
      authenticator.authenticate!(request)
      @current_api_client = Api::Client.new
    rescue Strata::Auth::AuthenticationError, Strata::Auth::InvalidSignature, Strata::Auth::MissingCredentials => e
      render_errors([ e.message ], :unauthorized) && return
    end
  end

  def pundit_user
    @current_api_client
  end
end
