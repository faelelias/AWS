resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = var.vpc_id
  description = "Sensedia HTTPS to Newcon APIs"
}

resource "aws_vpc_security_group_ingress_rule" "sensedia" {
  for_each          = var.sensedia_cidrs
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "web" {
  for_each                     = var.ec2_security_group_ids
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each                     = var.ec2_security_group_ids
  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
