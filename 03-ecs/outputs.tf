# ==============================================================================
# Locals
# ==============================================================================

locals {
  # app_host is the hostname the Rails app uses for password-reset link
  # generation. When no custom domain is set we fall back to the ALB DNS name.
  app_host = var.custom_domain != "" ? var.custom_domain : aws_lb.resumescorer.dns_name

  # app_url uses HTTPS when a custom domain (and ACM cert) exists, otherwise
  # plain HTTP on the ALB DNS name.
  app_url = var.custom_domain != "" ? "https://${var.custom_domain}" : "http://${aws_lb.resumescorer.dns_name}"
}

# ==============================================================================
# Outputs
# ==============================================================================

output "app_url" {
  description = "Public URL for the resumescorer application"
  value       = local.app_url
}

output "alb_dns_name" {
  description = "Raw ALB DNS name (used internally; prefer app_url)"
  value       = aws_lb.resumescorer.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.resumescorer.name
}

output "ecs_service_name" {
  value = aws_ecs_service.resumescorer.name
}
