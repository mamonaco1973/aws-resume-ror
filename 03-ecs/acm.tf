# ==============================================================================
# ACM Certificate and Route 53 DNS
# All resources in this file are conditional on var.custom_domain being set.
# When custom_domain is empty the app is reachable via plain HTTP on the ALB
# DNS name and none of these resources are created.
#
# DNS validation is fully automated — Terraform creates the CNAME record in
# Route 53, AWS validates it, and the cert is issued without any manual step.
# ==============================================================================

# ------------------------------------------------------------------------------
# ACM Certificate
# ------------------------------------------------------------------------------
resource "aws_acm_certificate" "resumescorer" {
  count             = var.custom_domain != "" ? 1 : 0
  domain_name       = var.custom_domain
  validation_method = "DNS"

  # create_before_destroy prevents downtime during cert renewal — the
  # new cert is issued before the old one is removed from the listener.
  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "resumescorer-cert" }
}

# ------------------------------------------------------------------------------
# Route 53 Hosted Zone (data source — zone must already exist)
# The parent zone is derived by stripping the first DNS label from the domain:
#   myjobs-ror.example.com  →  example.com
# ------------------------------------------------------------------------------
data "aws_route53_zone" "zone" {
  count        = var.custom_domain != "" ? 1 : 0
  name         = join(".", slice(split(".", var.custom_domain), 1, length(split(".", var.custom_domain))))
  private_zone = false
}

# ------------------------------------------------------------------------------
# DNS Validation Records
# ACM provides one CNAME per domain; Terraform creates it in Route 53.
# for_each handles the case where the cert covers multiple SANs.
# ------------------------------------------------------------------------------
resource "aws_route53_record" "cert_validation" {
  for_each = var.custom_domain != "" ? {
    for dvo in aws_acm_certificate.resumescorer[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone[0].zone_id
}

# Waits until AWS confirms the cert is issued before the HTTPS listener
# is allowed to reference it. Without this, apply would race and fail.
resource "aws_acm_certificate_validation" "resumescorer" {
  count                   = var.custom_domain != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.resumescorer[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ------------------------------------------------------------------------------
# Route 53 A Alias — custom domain → ALB
# An alias record is preferred over a CNAME for subdomain → ALB because
# AWS resolves it internally (no extra DNS hop) and it is free.
# ------------------------------------------------------------------------------
resource "aws_route53_record" "app" {
  count   = var.custom_domain != "" ? 1 : 0
  zone_id = data.aws_route53_zone.zone[0].zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = aws_lb.resumescorer.dns_name
    zone_id                = aws_lb.resumescorer.zone_id
    evaluate_target_health = true
  }
}
