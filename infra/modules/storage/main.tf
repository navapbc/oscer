resource "aws_s3_bucket" "storage" {
  bucket = var.name

  # Use a separate line to support automated terraform destroy commands
  force_destroy = var.is_temporary

  # checkov:skip=CKV_AWS_18:TODO(https://github.com/navapbc/template-infra/issues/507) Implement access logging

  # checkov:skip=CKV_AWS_144:Cross region replication not required by default
  # checkov:skip=CKV2_AWS_62:S3 bucket does not need notifications enabled
  # checkov:skip=CKV_AWS_21:Bucket versioning is not needed
}

# CORS configuration for browser-based direct uploads
# Allows web browsers to upload files directly to S3 (bypassing Rails server)
resource "aws_s3_bucket_cors_configuration" "storage" {
  count  = length(var.cors_allowed_origins) > 0 ? 1 : 0
  bucket = aws_s3_bucket.storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}
