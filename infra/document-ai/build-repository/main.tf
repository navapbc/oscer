data "aws_iam_role" "github_actions" {
  name = module.project_config.github_actions_role_name
}

data "external" "account_ids_by_name" {
  program = ["${path.module}/../../../bin/account-ids-by-name"]
}

locals {
  tags = merge(module.project_config.default_tags, {
    application      = "document-ai"
    application_role = "build-repository"
    description      = "Backend resources required for storing built release candidate artifacts to be used for deploying to environments."
  })

  # document-ai currently deploys only to the dev network
  dev_account_name = module.project_config.network_configs["dev"].account_name
  dev_account_id   = data.external.account_ids_by_name.result[local.dev_account_name]

  ecr_repo_name = "${module.project_config.project_name}-document-ai"
}

terraform {
  required_version = "~>1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.20.1"
    }
  }

  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  region = module.project_config.default_region
  default_tags {
    tags = local.tags
  }
}

module "project_config" {
  source = "../../project-config"
}

module "container_image_repository" {
  source               = "../../modules/container-image-repository"
  name                 = local.ecr_repo_name
  push_access_role_arn = data.aws_iam_role.github_actions.arn
  app_account_ids      = [local.dev_account_id]
}
