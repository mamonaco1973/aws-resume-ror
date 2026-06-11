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

# ALB DNS is known only after 03-ecs applies; passed in from apply.sh
variable "app_host" {
  description = "Public hostname for Devise password reset links"
  type        = string
  default     = ""
}
