# ==============================================================================
# Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "Public URL for the resumescorer application"
  value       = aws_lb.resumescorer.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.resumescorer.name
}

output "ecs_service_name" {
  value = aws_ecs_service.resumescorer.name
}
