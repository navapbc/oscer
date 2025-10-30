module "sandbox_config" {
  source                          = "./env-config"
  project_name                    = local.project_name
  app_name                        = local.app_name
  default_region                  = module.project_config.default_region
  environment                     = "sandbox"
  network_name                    = "dev"
  domain_name                     = "medicaid.navateam.com"
  enable_https                    = true
  has_database                    = local.has_database
  has_incident_management_service = local.has_incident_management_service
  enable_notifications            = local.enable_notifications

  # Enable and configure identity provider.
  enable_identity_provider = local.enable_identity_provider

  # Enables ECS Exec access for debugging or jump access.
  # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  # Defaults to `false`. Uncomment the next line to enable.
  # enable_command_execution = true

  service_override_extra_environment_variables = {
    ENABLE_LOOKBOOK = "true"
  }
}
