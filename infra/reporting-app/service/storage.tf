locals {
  storage_config = local.environment_config.storage_config
  bucket_name    = "${local.prefix}${local.storage_config.bucket_name}"

  # CORS origins for browser-based direct uploads
  # Temporary environments (PR previews) use the ALB endpoint directly since
  # they don't have a custom domain. Non-temporary environments use the custom domain.
  cors_allowed_origins = local.is_temporary ? [
    module.service.public_endpoint
    ] : module.domain.domain_name != "" ? [
    "https://${module.domain.domain_name}"
    ] : [
    module.service.public_endpoint
  ]
}

module "storage" {
  source               = "../../modules/storage"
  name                 = local.bucket_name
  is_temporary         = local.is_temporary
  cors_allowed_origins = local.cors_allowed_origins
}
