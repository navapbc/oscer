module "network" {
  source       = "../../modules/network/data"
  project_name = module.project_config.project_name
  name         = local.environment_config.network_name
}
resource "aws_secretsmanager_secret" "example" {
  name = "example-password"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = "your-password-here"
}
