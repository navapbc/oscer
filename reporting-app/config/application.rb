# frozen_string_literal: true

require_relative "boot"
require_relative "../lib/middleware/api_error_response.rb"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TemplateApplicationRails
  class Application < Rails::Application
    config.generators.test_framework = :rspec

    # Internationalization
    I18n.available_locales = [ :"en", :"es-US" ]
    I18n.default_locale = :"en"
    I18n.enforce_available_locales = true

    # Support nested locale files
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    config.time_zone = ENV["TIME_ZONE"] || "Eastern Time (US & Canada)" # Convenient for time display in local development

    config.view_component.previews.paths = [ "app/previews" ]
    config.view_component.generate.preview = true
    config.view_component.generate.locale = true
    config.view_component.generate.distinct_locale_files = true

    # Fetch authentication flow; default to cognito
    Rails.application.config.auth_adapter = ENV.fetch("AUTH_ADAPTER", "cognito")

    # Which reporting service to use. Valid values are:
    # "income_verification_service" - CMS's income verification as a service.
    #    Requires IVAAS_API_KEY, IVAAS_BASE_URL, and IVAAS_CLIENT_AGENCY_ID env
    #    variables to be set.
    # "reporting_app" - Built in application
    config.reporting_source = "reporting_app"

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])

    # Prevent the form_with helper from wrapping input and labels with separate
    # div elements when an error is present, since this breaks USWDS styling
    # and functionality.
    config.action_view.field_error_proc = Proc.new { |html_tag, instance|
      html_tag
    }

    config.active_record.strict_loading_by_default = true

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators do |g|
      g.factory_bot suffix: "factory"
    end

    config.after_initialize do
      CertificationBusinessProcess.start_listening_for_events
    end

    # Support UUID generation. This was a callout in the ActiveStorage guide
    # https://edgeguides.rubyonrails.org/active_storage_overview.html#setup
    Rails.application.config.generators { |g| g.orm :active_record, primary_key_type: :uuid }

    # Show a 403 Forbidden error page when Pundit raises a NotAuthorizedError
    config.action_dispatch.rescue_responses["Pundit::NotAuthorizedError"] = :forbidden

    config.exceptions_app = ->(env) { Middleware::ApiErrorResponse.new(Rails.public_path).call(env) }
  end
end
