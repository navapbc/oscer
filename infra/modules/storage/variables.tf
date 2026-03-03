variable "is_temporary" {
  description = "Whether the service is meant to be spun up temporarily (e.g. for automated infra tests). This is used to disable deletion protection."
  type        = bool
  default     = false
}

variable "name" {
  type        = string
  description = "Name of the AWS S3 bucket. Needs to be globally unique across all regions."
}

variable "cors_allowed_origins" {
  type        = list(string)
  description = "List of origins allowed for CORS requests (e.g., ['https://example.com']). Required for browser-based direct uploads."
  default     = []
}
