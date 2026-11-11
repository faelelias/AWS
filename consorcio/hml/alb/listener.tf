# Listener tecnico 8443 sem ingress no SG; necessario para health checks dos dois grupos.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web["primary"].arn
  }
  lifecycle { ignore_changes = [default_action] }
}

resource "aws_lb_listener" "health_only" {
  load_balancer_arn = aws_lb.api.arn
  port              = 8443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.web["primary"].arn
        weight = 1
      }
      target_group {
        arn    = aws_lb_target_group.web["standby"].arn
        weight = 1
      }
      stickiness {
        enabled  = true
        duration = 3600
      }
    }
  }
}
