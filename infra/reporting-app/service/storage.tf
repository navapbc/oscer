locals {
  storage_config = local.environment_config.storage_config
  bucket_name    = "${local.prefix}${local.storage_config.bucket_name}"

  # CORS origins for browser-based direct uploads
  # Use custom domain if available, otherwise use load balancer endpoint
  # This ensures preview environments (which use ALB DNS) also get CORS configured
  cors_allowed_origins = module.domain.domain_name != "" ? [
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
