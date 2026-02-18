locals {
  # Map from environment variable name to environment variable value
  # This is a map rather than a list so that variables can be easily
  # overridden per environment using terraform's `merge` function
  default_extra_environment_variables = {
    APP_HOST          = var.domain_name
    VA_API_HOST       = "https://sandbox-api.va.gov"
    VA_TOKEN_AUDIENCE = "https://deptva-eval.okta.com/oauth2/ausi3u00gw66b9Ojk2p7/v1/token"
    VA_TOKEN_HOST     = "https://sandbox-api.va.gov/oauth2/veteran-verification/system/v1/token"

    # Cloud provider for storage adapter selection
    # BUCKET_NAME is set in service/main.tf
    CLOUD_PROVIDER = "aws"

    # GoodJob background job processing (async mode)
    # Pool size accommodates Puma (5) + GoodJob (2) + buffer (1) = 8
    GOOD_JOB_EXECUTION_MODE = "async"
    GOOD_JOB_MAX_THREADS    = "2"
    DATABASE_POOL           = "8"
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
    VA_CLIENT_ID_CCG = {
      manage_method     = "manual"
      secret_store_name = "/${var.app_name}-${var.environment}/service/va-client-id-ccg"
    }
    VA_PRIVATE_KEY = {
      manage_method     = "manual"
      secret_store_name = "/${var.app_name}-${var.environment}/service/va-private-key"
    }
  }
}
