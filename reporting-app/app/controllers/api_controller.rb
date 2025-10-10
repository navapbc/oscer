# frozen_string_literal: true

class ApiController < ActionController::Metal
  ActionController::API.without_modules(:StrongParameters).each do |left|
    include left
  end

  ActiveSupport.run_load_hooks(:action_controller_api, self)
  ActiveSupport.run_load_hooks(:action_controller, self)

  include Pundit::Authorization

  def render_errors(errors, status = :unprocessable_entity)
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
      msgs = errors.details
    when Array
      msgs = errors
    when String
      msgs = [ errors ]
    else
      raise TypeError, "Unexpected errors type"
    end
    render json: { errors: msgs }, status: status
  end
  def render_data(data, status: :ok)
    render json: data, status: status
  end
end
