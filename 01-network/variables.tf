# ==============================================================================
# Input Variables
# ==============================================================================

variable "app_name" {
  description = "Application name used as a prefix for all resources"
  type        = string
  default     = "resumescorer"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "resumescorer_production"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "resumescorer"
}
