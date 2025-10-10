# frozen_string_literal: true

require "action_dispatch/middleware/public_exceptions"

# https://github.com/rails/rails/blob/main/actionpack/lib/action_dispatch/middleware/public_exceptions.rb
module Middleware
    class ApiErrorResponse < ::ActionDispatch::PublicExceptions
      def call(env)
        request      = ActionDispatch::Request.new(env)
        status       = request.path_info[1..-1].to_i
        content_type = request.formats.first
        body = { errors: [ Rack::Utils::HTTP_STATUS_CODES.fetch(status, Rack::Utils::HTTP_STATUS_CODES[500]) ] }

        render(status, content_type, body)
      end
    end
end
