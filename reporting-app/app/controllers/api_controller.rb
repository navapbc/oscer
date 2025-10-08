# frozen_string_literal: true

class ApiController < ActionController::Metal
  ActionController::API.without_modules(:StrongParameters).each do |left|
    include left
  end

  ActiveSupport.run_load_hooks(:action_controller_api, self)
  ActiveSupport.run_load_hooks(:action_controller, self)

  include Pundit::Authorization
end
