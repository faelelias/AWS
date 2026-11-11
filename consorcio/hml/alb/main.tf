locals {
  prefix        = "arn:${data.aws_partition.current.partition}"
  instance_arns = [for id in values(var.instance_ids) : "${local.prefix}:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${id}"]
}

resource "aws_lb" "api" {
  name                       = var.name
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = var.subnet_ids
  security_groups            = [aws_security_group.alb.id]
  preserve_host_header       = true
  enable_deletion_protection = true
  lifecycle {
    precondition {
      condition     = length(distinct([for s in data.aws_subnet.alb : s.availability_zone])) >= 2 && alltrue([for s in data.aws_subnet.alb : s.vpc_id == var.vpc_id])
      error_message = "ALB requer subnets da VPC em pelo menos duas AZs."
    }
    precondition {
      condition     = data.aws_instance.web["primary"].availability_zone != data.aws_instance.web["standby"].availability_zone && alltrue([for i in data.aws_instance.web : i.vpc_id == var.vpc_id && contains([for s in data.aws_subnet.alb : s.availability_zone], i.availability_zone)])
      error_message = "EC2 devem estar na VPC e em AZs distintas habilitadas no ALB."
    }
    precondition {
      condition     = !var.enable_automatic_failover || (var.standby_prepared && var.accept_overlap_risk)
      error_message = "Prepare a reserva e declare aceite do risco antes de habilitar failover automatico."
    }
  }
}
