# ==============================================================================
# Application Load Balancer
# Public ALB in public subnets.
#
# With custom_domain set:
#   HTTP/80  →  301 redirect to HTTPS
#   HTTPS/443 → TLS termination with ACM cert → Rails on port 3000
#
# Without custom_domain:
#   HTTP/80  →  forward directly to Rails on port 3000
# ==============================================================================

resource "aws_lb" "resumescorer" {
  name               = "resumescorer-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    data.aws_subnet.pub-subnet-1.id,
    data.aws_subnet.pub-subnet-2.id
  ]

  tags = { Name = "resumescorer-alb" }
}

resource "aws_lb_target_group" "resumescorer" {
  name        = "resumescorer-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.ecs-vpc.id
  target_type = "ip"

  health_check {
    path                = "/users/sign_in"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "resumescorer-tg" }
}

# ------------------------------------------------------------------------------
# HTTP listener (custom domain) — permanent redirect to HTTPS
# Keeps port 80 open so bookmarked or typed HTTP URLs still work; they
# are immediately bounced to HTTPS with a 301 that browsers cache.
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "resumescorer_http_redirect" {
  count             = var.custom_domain != "" ? 1 : 0
  load_balancer_arn = aws_lb.resumescorer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ------------------------------------------------------------------------------
# HTTP listener (no custom domain) — forward directly to ECS
# Used when no custom domain is configured; the app is served over plain
# HTTP on the ALB DNS name.
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "resumescorer_http_forward" {
  count             = var.custom_domain != "" ? 0 : 1
  load_balancer_arn = aws_lb.resumescorer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.resumescorer.arn
  }
}

# ------------------------------------------------------------------------------
# HTTPS listener — TLS termination at the ALB (only with custom domain)
# The ACM cert is attached here. Traffic from the ALB to ECS tasks is
# plain HTTP inside the VPC — no need for end-to-end TLS on private links.
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "resumescorer_https" {
  count             = var.custom_domain != "" ? 1 : 0
  load_balancer_arn = aws_lb.resumescorer.arn
  port              = 443
  protocol          = "HTTPS"
  # TLS 1.2+ policy — drops TLS 1.0/1.1 which are deprecated
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.resumescorer[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.resumescorer.arn
  }
}
