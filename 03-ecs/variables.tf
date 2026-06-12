# ==============================================================================
# Input Variables
# ==============================================================================

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# S3 bucket name passed in from apply.sh (captured from 01-network output)
variable "s3_bucket_name" {
  description = "S3 bucket for ActiveStorage uploads"
  type        = string
}

variable "smtp_server" {
  description = "SMTP server hostname (plain env var — not sensitive)"
  type        = string
  default     = "smtp.improvmx.com"
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = string
  default     = "587"
}

variable "custom_domain" {
  description = "Custom domain (e.g. myjobs-ror.example.com). Leave empty to use the ALB DNS name over HTTP. The parent hosted zone is looked up automatically."
  type        = string
  default     = ""
}
