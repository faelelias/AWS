resource "aws_lb_target_group" "web" {
  for_each             = var.instance_ids
  name_prefix          = each.key == "primary" ? "ncp-" : "ncs-"
  port                 = 443
  protocol             = "HTTPS"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 0
  health_check {
    protocol            = "HTTPS"
    path                = var.health_check_path
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 3600
  }
}

resource "aws_lb_target_group_attachment" "web" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.web[each.key].arn
  target_id        = each.value
  port             = 443
}
