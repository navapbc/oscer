module "staging_config" {
  source                          = "./env-config"
  project_name                    = local.project_name
  app_name                        = local.app_name
  default_region                  = module.project_config.default_region
  environment                     = "staging"
  network_name                    = "staging"
  domain_name                     = null
  enable_https                    = false
  has_database                    = local.has_database
  has_incident_management_service = local.has_incident_management_service
  enable_identity_provider        = local.enable_identity_provider
  enable_notifications            = local.enable_notifications
  enable_document_data_extraction = local.enable_document_data_extraction
  enable_sms_notifications        = local.enable_sms_notifications

  # Enables ECS Exec access for debugging or jump access.
  # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  # Defaults to `false`. Uncomment the next line to enable.
  # enable_command_execution = true

  service_override_extra_environment_variables = {
    # Demo certification seeding UI. Creates real Certification records with no
    # authentication, so it stays disabled by default. To run UAT seeding in
    # this (non-prod) environment, flip this to "true" and re-deploy; set it
    # back to "false" afterward. Production must remain "false".
    FEATURE_DEMO_CERTIFICATIONS = "false"
  }
}
