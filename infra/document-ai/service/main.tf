locals {
  environment  = var.environment_name
  aws_region   = module.project_config.default_region
  project_name = module.project_config.project_name

  tags = merge(module.project_config.default_tags, {
    environment = local.environment
    application = "document-ai"
    description = "Document AI service resources created in ${local.environment} environment"
  })

  # document-ai uses the dev network (expand this map when adding more environments)
  network_name = {
    dev = "dev"
  }[local.environment]

  domain_name = "document-ai.${local.environment}.medicaid.navateam.com"
  hosted_zone = module.project_config.network_configs[local.network_name].domain_config.hosted_zone

  # Prefix for resources created by the external module.
  # Keep short: ALB name is "${doc_ai_project_name}-alb" (32-char AWS limit).
  # "cem-docai-dev-alb" = 18 chars ✓
  doc_ai_project_name = "cem-docai-${local.environment}"

  # S3 bucket for document storage (must be globally unique)
  s3_bucket_name = "community-engagement-medicaid-document-ai-${local.environment}"

  # ECR repository created by the build-repository layer
  ecr_repo_name = "${local.project_name}-document-ai"

  # Extract bare ALB hostname from the module's service_url output (strips https://)
  alb_dns_name = trimprefix(trimprefix(module.document_ai.service_url, "https://"), "http://")
}

terraform {
  required_version = "~>1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81.0, < 6.47.1"
    }
  }

  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  region = local.aws_region
  default_tags {
    tags = local.tags
  }
}

module "project_config" {
  source = "../../project-config"
}

# Look up the existing VPC and subnets via tags set by infra/networks
module "network" {
  source       = "../../modules/network/data"
  name         = local.network_name
  project_name = local.project_name
}

# ECR repository created by infra/document-ai/build-repository
data "aws_ecr_repository" "document_ai" {
  name = local.ecr_repo_name
}

# ACM certificate for the document-ai domain (provisioned via infra/networks)
data "aws_acm_certificate" "document_ai" {
  domain   = local.domain_name
  statuses = ["ISSUED"]
}

# Route53 hosted zone for creating the service's DNS record
data "aws_route53_zone" "zone" {
  name = local.hosted_zone
}

# Canonical ALB hosted zone ID for Route53 alias records (us-east-1 ALBs)
data "aws_elb_hosted_zone_id" "main" {
  load_balancer_type = "application"
}

# ---------------------------------------------------------------------------
# Document AI service
# ---------------------------------------------------------------------------
module "document_ai" {
  source = "github.com/navapbc/strata-service-document-ai//deploy/terraform/aws?ref=main"

  project_name = local.doc_ai_project_name
  environment  = local.environment
  aws_region   = local.aws_region

  # Networking — use the existing project VPC
  create_vpc         = false
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids

  # Container image from the project ECR (build-repository must be applied first)
  create_ecr      = false
  container_image = "${data.aws_ecr_repository.document_ai.repository_url}:${var.image_tag}"

  # Storage
  s3_bucket_name = local.s3_bucket_name

  # AI backend
  aws_model = "textract"

  # TLS — uses the cert provisioned in infra/networks
  acm_certificate_arn = data.aws_acm_certificate.document_ai.arn

  # WAF disabled for dev to reduce cost
  create_waf = false

  # Dev-safe: allow terraform destroy without manual intervention
  enable_deletion_protection   = false
  kms_deletion_window_days     = 7
  secrets_recovery_window_days = 0
  dynamodb_deletion_protection = false
}

# Route53 alias record pointing the domain at the service ALB
resource "aws_route53_record" "document_ai" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}
