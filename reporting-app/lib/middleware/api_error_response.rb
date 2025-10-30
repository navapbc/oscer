# frozen_string_literal: true

require "action_dispatch/middleware/public_exceptions"

# https://github.com/rails/rails/blob/main/actionpack/lib/action_dispatch/middleware/public_exceptions.rb
module Middleware
    class ApiErrorResponse < ::ActionDispatch::PublicExceptions
      def initialize(public_path)
        super

        @default_exceptions_app = ::ActionDispatch::PublicExceptions.new(@public_path)
        @api_path_prefix = "/api"
      end

      def call(env)
        return api_handle_path(env) if is_api_path?(env)

        @default_exceptions_app.call(env)
      end

      def is_api_path?(env)
        raw_path_info = env["action_dispatch.original_path"]
        if !::Rack::Utils.valid_path?(raw_path_info)
          return false
        end

        path = ::Rack::Utils.clean_path_info(raw_path_info)

        # match any subpath (/api/.*) or root (/api$) of the prefix
        if /^#{Regexp.escape(@api_path_prefix)}(\/|$)/.match?(path)
          return true
        end

        false
      end

      private

      # custom API helpers

      def api_handle_path(env)
        request      = ActionDispatch::Request.new(env)
        status       = request.path_info[1..-1].to_i

        content_type = api_content_type(request)

        body = api_body_for_status(status)


        if env["action_dispatch.original_request_method"] == "HEAD"
          render_format(status, content_type, "")
        else
          render(status, content_type, body)
        end
      end

      def api_content_type(request)
        begin
          content_type = request.formats.first
        rescue ActionDispatch::Http::MimeNegotiation::InvalidType
          content_type = Mime[:json]
        end

        # account for
        # ShowExceptions.fallback_to_html_format_if_invalid_mime_type, as we
        # want the default to be JSON and generally the API should never be
        # returning HTML, but especially as a error response
        if content_type != Mime[:html]
          return content_type
        end

        Mime[:json]
      end

      def api_body_for_status(status)
        { errors: [ Rack::Utils::HTTP_STATUS_CODES.fetch(status, Rack::Utils::HTTP_STATUS_CODES[500]) ] }
      end

      # parent overrides

      def render_html(status)
        # effectively disable the fallback HTML logic
        render_format(status, Mime[:json], api_body_for_status(status).to_json)
      end
    end
end
