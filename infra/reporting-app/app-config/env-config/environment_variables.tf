locals {
  # Map from environment variable name to environment variable value
  # This is a map rather than a list so that variables can be easily
  # overridden per environment using terraform's `merge` function
  default_extra_environment_variables = {
    APP_HOST = var.domain_name
  }

  # Configuration for secrets
  # List of configurations for defining environment variables that pull from SSM parameter
  # store. Configurations are of the format
  # {
  #   ENV_VAR_NAME = {
  #     manage_method     = "generated" # or "manual" for a secret that was created and stored in SSM manually
  #     secret_store_name = "/ssm/param/name"
  #   }
  # }
  secrets = {
    SECRET_KEY_BASE = {
      manage_method     = "generated"
      secret_store_name = "/${var.app_name}-${var.environment}/service/rails-secret-key-base"
    }
    API_SECRET_KEY = {
      manage_method     = "generated"
      secret_store_name = "/${var.app_name}-${var.environment}/service/api-secret-key"
    }
  }
}
